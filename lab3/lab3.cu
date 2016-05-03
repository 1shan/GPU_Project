#include "lab3.h"
#include <cstdio>
#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <cuda_runtime.h>


__device__ __host__ int CeilDiv(int a, int b) { return (a-1)/b + 1; }
__device__ __host__ int CeilAlign(int a, int b) { return CeilDiv(a, b) * b; }

__global__ void SimpleClone(
	const float *background,
	const float *target,
	const float *mask,
	float *output,
	const int wb, const int hb, const int wt, const int ht,
	const int oy, const int ox
)
{
	const int xt = blockIdx.x * blockDim.x + threadIdx.x; //target.x
	const int yt = blockIdx.y * blockDim.y + threadIdx.y; //target.y

	const int curt = wt*yt+xt; 
	//自己在target的位置
	//不超過target 且在mask位置gray值>127.f
	if (yt < ht && xt < wt && mask[curt] > 127.0f) {
		const int yb = oy+yt, xb = ox+xt;
		const int curb = wb*yb+xb;//自己在background的位置
		if (0 <= yb && yb < hb && 0 <= xb && xb < wb) {
			output[curb * 3 + 0] = target[curt * 3 + 0];
			output[curb * 3 + 1] = target[curt * 3 + 1];
			output[curb * 3 + 2] = target[curt * 3 + 2];
		}
	}
}

__global__ void CalculateFixed(
	const float *background,
	const float *target,
	const float *mask,
	float *fixed,
	const int wb, const int hb, const int wt, const int ht,
	const int oy, const int ox
	)
{
	const int xt = blockDim.x * blockIdx.x + threadIdx.x;
	const int yt = blockDim.y * blockIdx.y + threadIdx.y;
	const int curt = wt * yt + xt;

	float t_sum, b_sum;

	if (yt < ht && xt < wt) {
		const int yb = oy + yt, xb = ox + xt;//background.x background.y
		const int curb = wb*yb + xb;//background.cu0ent

		for (int i = 0; i < 3; i++){
			t_sum = 0;
			b_sum = 0;

			//檢查鄰居是否在target裡    

			if (xt - 1 >= 0){
				b_sum += mask[(curt - 1)] < 127.0 ? background[(curb - 1) * 3 + i] : 0;
				t_sum += target[(curt - 1) * 3 + i];
			}
			else{
				b_sum += background[(curb - 1) * 3 + i];
				t_sum += target[(curt)* 3 + i];
			}

			if (xt + 1 < wt){
				b_sum += mask[(curt + 1)] < 127.0 ? background[(curb + 1) * 3 + i] : 0;
				t_sum += target[(curt + 1) * 3 + i];
			}
			else{
				b_sum += background[(curb + 1) * 3 + i];
				t_sum += target[(curt)* 3 + i];
			}

			if (yt - 1 >= 0){
				b_sum += mask[(curt - wt)] < 127.0 ? background[(curb - wb) * 3 + i] : 0;
				t_sum += target[(curt - wt) * 3 + i];
			}
			else{
				b_sum += background[(curb - wb) * 3 + i];
				t_sum += target[(curt)* 3 + i];
			}

			if (yt + 1 < ht){
				b_sum += mask[(curt + wt)] < 127.0 ? background[(curb + wb) * 3 + i] : 0;
				t_sum += target[(curt + wt) * 3 + i];
			}
			else{
				b_sum += background[(curb + wb) * 3 + i];
				t_sum += target[(curt)* 3 + i];
			}

			fixed[curt * 3 + i] = 4.0*target[curt * 3 + i] - t_sum + b_sum;
		}
	}
}

__global__ void PoissonImageCloningInteration(
	const float *fixed,
	const float *mask,
	const float *target, //buf1
	float *output,		 //buf2
	const int wt,
	const int ht)
{

	const int xt = blockIdx.x * blockDim.x + threadIdx.x; //target.x
	const int yt = blockIdx.y * blockDim.y + threadIdx.y; //target.y
	const int curt = wt * yt + xt;
	float w = 1.4; //SOR parameters

	float neibor_sum = 0;
	if (yt < ht && xt < wt && mask[curt] > 127.0f){
		for (int i = 0; i < 3; i++){
			neibor_sum = 0;
			//左右鄰居有白的都要++

			// West
			if (xt - 1 >= 0 && mask[(curt - 1)] > 127.0f){
				neibor_sum += target[(curt - 1) * 3 + i];
			}
			// East
			if (xt + 1 < wt && mask[(curt + 1)] > 127.0f){
				neibor_sum += target[(curt + 1) * 3 + i];
			}
			// North
			if (yt - 1 >= 0 && mask[(curt - wt)] > 127.0f){
				neibor_sum += target[(curt - wt) * 3 + i];
			}
			// South
			if (yt + 1 < ht && mask[(curt + wt)] > 127.0f){
				neibor_sum += target[(curt + wt) * 3 + i];
			}
			//* This part for original jacobi method * //
			//output[curt * 3 + i] = (fixed[curt * 3 + i] + neibor_sum) / 4;

			//* This part for  acceleration *//
			output[curt * 3 + i] = w * (fixed[curt * 3 + i] + neibor_sum) / 4 + (1.0 - w) * output[curt * 3 + i];
		}
	}
}
void PoissonImageCloning(
	const float *background, //Wb*Hb
	const float *target, //Wt*Ht
	const float *mask,// 1 channel, 0.0f/255.0f -> false/true. 
	float *output, //Wb*Hb
	const int wb, const int hb, const int wt, const int ht,
	const int oy, const int ox
	)
{
	//cudaMemcpy(output, background, wb*hb*sizeof(float)*3, cudaMemcpyDeviceToDevice);
	//SimpleClone<<<dim3(CeilDiv(wt,32), CeilDiv(ht,16)), dim3(32,16)>>>(
	//	background, target, mask, output,
	//	wb, hb, wt, ht, oy, ox
	//);

	//set up
	float *fixed, *buf1, *buf2;
	cudaMalloc(&fixed, 3 * wt*ht*sizeof(float));
	cudaMalloc(&buf1 , 3 * wt*ht*sizeof(float));
	cudaMalloc(&buf2 , 3 * wt*ht*sizeof(float));

	//initialize the iteration
	dim3 gdim(CeilDiv(wt, 32), CeilDiv(ht, 16)), bdim(32, 16);
	CalculateFixed <<<gdim, bdim >>>(background, target, mask, fixed,wb, hb, wt, ht, oy, ox);

	cudaMemcpy(buf1, target, sizeof(float) * 3 * wt * ht, cudaMemcpyDeviceToDevice);

	//iterate
	for (int i = 0; i < 5000; ++i){
		PoissonImageCloningInteration <<<gdim, bdim >>>(fixed, mask, buf1, buf2, wt, ht);
		PoissonImageCloningInteration <<<gdim, bdim >>>(fixed, mask, buf2, buf1, wt, ht);
	}
	////copy the image back
	cudaMemcpy(output, background, wb*hb*sizeof(float) * 3, cudaMemcpyDeviceToDevice);
	SimpleClone <<<gdim, bdim >>>(background, buf1, mask, output, wb, hb, wt, ht, oy, ox);
	
	//clean up
	cudaFree(fixed);
	cudaFree(buf1);
	cudaFree(buf2);
	
}































