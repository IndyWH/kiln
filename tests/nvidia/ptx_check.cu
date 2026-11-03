// Kiln Linux: does a CUDA program built with nvcc's default settings run on the GPU?
// Default settings make PTX for an old GPU generation, which the driver has to translate.
// Build and run: /opt/cuda/bin/nvcc tests/nvidia/ptx_check.cu -o /tmp/ptx_check && /tmp/ptx_check
#include <cstdio>

__global__ void fill(int *data, int size) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < size) data[i] = i * 2;
}

int main() {
    const int size = 1024;
    int *gpu = nullptr;
    int host[size];

    cudaError_t status = cudaMalloc(&gpu, sizeof(host));
    if (status != cudaSuccess) {
        printf("FAILED: %s\n", cudaGetErrorString(status));
        return 1;
    }
    fill<<<4, 256>>>(gpu, size);
    status = cudaGetLastError();
    if (status != cudaSuccess) {
        printf("FAILED: %s\n", cudaGetErrorString(status));
        return 1;
    }
    cudaMemcpy(host, gpu, sizeof(host), cudaMemcpyDeviceToHost);
    cudaFree(gpu);
    for (int i = 0; i < size; i++) {
        if (host[i] != i * 2) {
            printf("FAILED: wrong answer at %d\n", i);
            return 1;
        }
    }
    printf("PASSED: the GPU ran it and got the right answers.\n");
    return 0;
}
