#include "counting.h"
#include "SyncedMemory.h"
#include <cstdio>
#include <cassert>
#include <thrust/scan.h>
#include <thrust/transform.h>
#include <thrust/functional.h>
#include <thrust/device_ptr.h>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <thrust/copy.h>
#include <thrust/execution_policy.h>
#include <thrust/iterator/counting_iterator.h>
#include <cstdlib>
#include <iostream>
#include <vector>

using namespace std;

__device__ __host__ int CeilDiv(int a, int b) {

	return (a - 1) / b + 1;
}
__device__ __host__ int CeilAlign(int a, int b) {

	return CeilDiv(a, b) * b;
}
__global__ void BuildTree_1st(const char* text, int* bottom, int bottom_size){

	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	if (idx < bottom_size){

		if (text[idx] == '\n') bottom[idx] = 0;
		else bottom[idx] = 1;
		//printf("%d, %d\n", idx, bottom[idx]);
	}

}
struct ifone{
	__host__ __device__ bool operator()(const int x){
		return (x == 1);
	}
};
__global__ void dropvector(char* text, int* pos, int text_size){
	
	
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	
	//printf("[i:%d=%c]",idx, text[idx]);

	char a = 0;
	if (idx % 2 == 0 && text[idx]!='\n' && text[idx+1]!='\n'){
		a = text[idx];
		text[idx] = text[idx + 1];
		text[idx + 1] = a;
	}



}
/*
__global__ int trace(){

	//check有沒有爸
	//if ( idx /2 >= text_size/(hight+1)*2)
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	int height = 0;
	int length = 0;


	//bottom up

	if (idx % 2 == 1){ //right node
		if (idx / 2 >= text_size / (hight + 1) * 2){
			while (idx /= 2, height += 1){
				if ([height][idx] != 0){ //dad not 0.
					if ((idx) % 2 == 0){// is dad right or left?
						//yes . dad is left.
						if ([height][idx - 1] == 0){ //is dad's left = 0?
							//yes. 
							length += [height][idx];
							idx = idx - 1;

							while ((idx * 2) + 1, height -= 1) {// top down
								if ([height][idx] != 0){
									length += [height][idx];
									return length;
								}
							}
						}
						else{//爸爸的左邊不是零
							continue;
						}
					}
					else{//dad is right
						length += [height][idx];
						return length;
					}
				}
				else{//dad is 0.
					length = 1;
					return length;
				}
				if (!(idx / 2 >= text_size / (hight + 1) * 2)) { //if no parent 怪怪的
					return length;
				}
			}
		}
		else{//此點沒有爸



		}
	}
	else{  //left node

		//左節點 先左移
		//左移 is 0?
		if ([idx - 1] != 0){ //左移非零
			length += [height][idx];
		}
		else{//左移為零
			length = 1;
			return length;

		}
		idx = idx - 1; //左移
		if ((idx / 2) >= text_size / (hight + 1) * 2){ //if node HAVE parent
			while (idx /= 2, height += 1){
				if ([height][idx] != 0){ //dad not 0.
					if (idx % 2 == 0){// is dad right or left?
						//yes . dad is left.
						if ([height][idx - 1] == 0){ //is dad's left = 0?
							//yes. 
							//topdown
							length += [height][idx];
							while ((idx * 2) + 1, height -= 1) {
								if ([height][idx] != 0){
									length += [height][idx];
									return length;
								}
							}

						}
						else{
							length += [height][idx];
							return;
						}
					}

				}
				else {//if dad is 0.
					length[]
				}
				if (!(idx / 2 >= text_size / (hight + 1) * 2)) return;
			}
		}
		else{ // node NOT have parent
			return;
		}
	}

	else //no parent.
	{
		return;
	}


}*/

__global__ void BuildTree_other(int *Pre_layer, int *layer, int layertext){
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	if (idx < layertext){
		if (Pre_layer[2 * idx] & Pre_layer[2 * idx + 1])
			layer[idx] = Pre_layer[2 * idx + 1] + Pre_layer[2 * idx];
		else
			layer[idx] = 0;
		//printf("i=%d idx = %d, %d\n", layertext, idx, layer[idx]);
	}
}
void CountPosition(const char *text, int *pos, int text_size)
{
	//thrust::host_vector <int> H(4);
	int arrSize = text_size;
	int  *treeLayerBegin[9]; //record layer begin position.
	int** treeArray = 0;
	treeArray = (int **)malloc(9 * sizeof(int*));
	for (int i = 0; i < 9; i++){
		treeArray[i] = (int *)malloc(sizeof(int)*arrSize);
		treeLayerBegin[i] = treeArray[i];
		cudaMalloc((void**)&treeLayerBegin[i], sizeof(int)*arrSize);
		arrSize = (arrSize % 2) ? (arrSize - 1) / 2 : arrSize / 2;
	}

	int blockdim = (text_size / 512) + 1; //16要改512
	BuildTree_1st << <blockdim, 512 >> >(text, treeLayerBegin[0], text_size);

	int layertext = (text_size % 2) ? (text_size - 1) / 2 : text_size / 2;
	int a = 256;//??
	for (int i = 1; i < 9; i++){
		blockdim = (layertext) / 256 + 1;
		BuildTree_other << <blockdim, a >> > (treeLayerBegin[i - 1], treeLayerBegin[i], layertext);
		a /= 2;
		layertext /= 2;
	}



}




int ExtractHead(const int *pos, int *head, int text_size)
{
	int *buffer;
	int nhead = 0;
	cudaMalloc(&buffer, sizeof(int)*text_size * 2); // this is enough
	thrust::device_ptr<const int> pos_d(pos);
	thrust::device_ptr<int> head_d(head), flag_d(buffer), cumsum_d(buffer + text_size);

	// TODO
	
	thrust::sequence(flag_d, cumsum_d);
	nhead = thrust::copy_if(flag_d,cumsum_d, pos_d, head_d,ifone()) - head_d;
	

	cudaFree(buffer);
	return nhead;
}

void Part3(char *text, int *pos, int *head, int text_size, int n_head)
{

	int blockdim = (text_size / 512) + 1; //16要改512
	dropvector << <blockdim, 512 >> >(text, pos, text_size);





}
