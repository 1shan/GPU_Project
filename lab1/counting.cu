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
#include <thrust/execution_policy.h>
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
__global__ void BuildTree_layer(const char* text, int* bottom, int bottom_size){

	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	if (idx < bottom_size){
		if (text[idx] == '\n') bottom[idx] = 0;
		else bottom[idx] = 1;
		
		


	}

}
/*__global__ void BuildTree_other(const char* text, int *pos, int layersize){

int idx = blockIdx.x * blockDim.x + threadIdx.x;



}
*/

void CountPosition(const char *text, int *pos, int text_size)
{
	int bottom_size = text_size;
	vector<int*> perlayerStart; // record layer begin position.
	int TREE_index = 0;
	int *temp = 0;

	cudaMalloc(&temp, sizeof(int)*bottom_size);
	perlayerStart.push_back(temp);
	int grid_dim = bottom_size >> 5 + 1;
	if (TREE_index == 0) BuildTree_layer << <grid_dim, 32 >> >(text, temp, bottom_size);










}

int ExtractHead(const int *pos, int *head, int text_size)
{
	int *buffer;
	int nhead = 0;
	cudaMalloc(&buffer, sizeof(int)*text_size * 2); // this is enough
	thrust::device_ptr<const int> pos_d(pos);
	thrust::device_ptr<int> head_d(head), flag_d(buffer), cumsum_d(buffer + text_size);

	// TODO

	cudaFree(buffer);
	return nhead;
}

void Part3(char *text, int *pos, int *head, int text_size, int n_head)
{







}
