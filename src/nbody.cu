#include <cuda_runtime.h>
#include <vector>
#include <iostream>
#include <fstream>
#include <sstream>
#include <cmath>
#include <cstring>
#include "world.h"


// =====================
// CUDA Kernel
// =====================
// __global__ void simulateStepKernel(Particle* particles,
//                                    Particle* newParticles,
//                                    int N,
//                                    float deltaTime,
//                                    float cullRadius)
// {
//     int i = blockIdx.x * blockDim.x + threadIdx.x;
//     if (i >= N) return;

//     // Particle p;
//     // p.id  = particles[i].id;
//     // p.mass = particles[i].mass;
//     // p.position.x = particles[i].position.x;
//     // p.position.y = particles[i].position.y;
//     // p.velocity.x = particles[i].velocity.x;
//     // p.velocity.y = particles[i].velocity.y;
//     Particle p = particles[i];
//     Vec2 force = {0.0f, 0.0f};

//     for (int j = 0; j < N; j++) {
//         if (p.id == particles[j].id) continue;
//         force = force + computeForce(p, particles[j], cullRadius);
//     }
//     newParticles[i] = updateParticle(p, force, deltaTime);
// }


// __global__ void simulateStepKernel(Particle* particles,
//                                    Particle* newParticles,
//                                    int N,
//                                    float deltaTime,
//                                    float cullRadius)
// {
//     extern __shared__ Particle tile[];   // shared memory tile

//     int i = blockIdx.x * blockDim.x + threadIdx.x;
//     if (i >= N) return;

//     Particle p = particles[i];
//     Vec2 force = {0.0f, 0.0f};

//     int tileSize = blockDim.x;

//     // ---- Loop over tiles ----
//     for (int t = 0; t < N; t += tileSize) {

//         int idx = t + threadIdx.x;

//         // Load a tile of particles into shared memory
//         if (idx < N)
//             tile[threadIdx.x] = particles[idx];
//         else {
//             // padding，避免越界
//             tile[threadIdx.x].id = -1;
//         }

//         __syncthreads();

//         // ---- Compute forces with this tile ----
//         for (int j = 0; j < tileSize; j++) {

//             Particle other = tile[j];
//             if (other.id < 0) continue;         // padding
//             if (p.id == other.id) continue;     // same particle skip
//             // if ((p.position - particles[j].position).length() < cullRadius)
//             force = force + computeForce(p, other, cullRadius);
//         }

//         __syncthreads(); // ensure all threads finish tile
//     }

//     // write back
//     newParticles[i] = updateParticle(p, force, deltaTime);
// }
__global__ void simulateStepKernel(Particle* particles,
                                   Particle* newParticles,
                                   int N,
                                   float deltaTime,
                                   float cullRadius)
{
    extern __shared__ Particle tile[];   // shared memory tile

    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;

    Particle p = particles[i];
    Vec2 force = {0.0f, 0.0f};

    int tileSize = blockDim.x;

    // ---- Loop over tiles ----
    for (int t = 0; t < N; t += tileSize) {

        int idx = t + threadIdx.x;

        // Load a tile of particles into shared memory
        if (idx < N)
            tile[threadIdx.x] = particles[idx];
        else {
            // padding，避免越界
            tile[threadIdx.x].id = -1;
        }

        __syncthreads();

        // ---- Compute forces with this tile ----
        for (int j = 0; j < tileSize; j++) {

            Particle other = tile[j];
            if (other.id < 0) continue;         // padding
            if (p.id == other.id) continue;     // same particle skip
            // if ((p.position - particles[j].position).length() < cullRadius)
            force = force + computeForce(p, other, cullRadius);
        }

        __syncthreads(); // ensure all threads finish tile
    }

    // write back
    newParticles[i] = updateParticle(p, force, deltaTime);
}

__global__ void printParticlesKernel(Particle* d_particles, int N)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;

    printf("[GPU] i=%d id=%d mass=%f pos=(%f,%f) vel=(%f,%f)\n",
           i,
           d_particles[i].id,
           d_particles[i].mass,
           d_particles[i].position.x,
           d_particles[i].position.y,
           d_particles[i].velocity.x,
           d_particles[i].velocity.y);
}


void simulateStepGPU(Particle* h_particles,
                     Particle* h_newParticles,
                     int N,
                     float deltaTime,
                     float cullRadius)
{
    Particle *d_particles;
    Particle *d_newParticles;
    cudaMalloc(&d_particles, N * sizeof(Particle));
    cudaMalloc(&d_newParticles, N * sizeof(Particle));
    cudaMemcpy(d_particles, h_particles, N * sizeof(Particle), cudaMemcpyHostToDevice);
    
    int blockSize = 256;
    int numBlocks = (N + blockSize - 1) / blockSize;
    size_t sharedMemSize = blockSize * sizeof(Particle);

    simulateStepKernel<<<numBlocks, blockSize, sharedMemSize>>>(d_particles,
                                                d_newParticles,
                                                N,
                                                deltaTime,
                                                cullRadius);
    
    cudaDeviceSynchronize();

    cudaMemcpy(h_newParticles, d_newParticles, N * sizeof(Particle), cudaMemcpyDeviceToHost);
    // for(int i = 0; i < 5; i++) {
    //     std::cout << "After Kernel Particle " << h_newParticles[i].id
    //             << " pos=(" << h_newParticles[i].position.x << "," << h_newParticles[i].position.y << ")"
    //             << " vel=(" << h_newParticles[i].velocity.x << "," << h_newParticles[i].velocity.y << ")\n";
    // }
    cudaFree(d_particles);
    cudaFree(d_newParticles);
}

