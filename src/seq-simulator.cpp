#include "make_unique.h"
#include "world.h"
#include "quad-tree.h"
#include <algorithm>
#include <iostream>

// TASK 1

// NOTE: You may modify any of the contents of this file, but preserve all function types and names.
// You may add new functions if you believe they will be helpful.

const int QuadTreeLeafSize = 8;
class SequentialNBodySimulator : public INBodySimulator
{
public:
    std::shared_ptr<QuadTreeNode> buildQuadTree(std::vector<Particle> & particles, Vec2 bmin, Vec2 bmax)
    {
       // TODO: implement a function that builds and returns a quadtree containing particles.
        auto node = std::make_shared<QuadTreeNode>();
        if(particles.size() <= QuadTreeLeafSize){
            node->isLeaf = true;
            node->particles = particles;
            return node;
        }
        node -> isLeaf = false;
        Vec2 center = (bmin + bmax) * 0.5f;
        std::vector<Particle> quadrants[4];
        for(auto & p : particles){
            int quadrant = 0;
            if(p.position.x >= center.x) quadrant += 1;
            if(p.position.y >= center.y) quadrant += 2;
            quadrants[quadrant].push_back(p);
        }
        node -> children[0] = buildQuadTree(quadrants[0], bmin, center);
        node -> children[1] = buildQuadTree(quadrants[1], Vec2(center.x, bmin.y), Vec2(bmax.x, center.y));
        node -> children[2] = buildQuadTree(quadrants[2], Vec2(bmin.x, center.y), Vec2(center.x, bmax.y));
        node -> children[3] = buildQuadTree(quadrants[3], center, bmax);
        return node;
    }
    virtual std::shared_ptr<AccelerationStructure> buildAccelerationStructure(std::vector<Particle> & particles)
    {
        // build quad-tree
        auto quadTree = std::make_shared<QuadTree>();

        // find bounds
        Vec2 bmin(1e30f, 1e30f);
        Vec2 bmax(-1e30f, -1e30f);

        for (auto & p : particles)
        {
            bmin.x = fminf(bmin.x, p.position.x);
            bmin.y = fminf(bmin.y, p.position.y);
            bmax.x = fmaxf(bmax.x, p.position.x);
            bmax.y = fmaxf(bmax.y, p.position.y);
        }

        quadTree->bmin = bmin;
        quadTree->bmax = bmax;

        // build nodes
        quadTree->root = buildQuadTree(particles, bmin, bmax);
        if (!quadTree->checkTree()) {
          std::cout << "Your Tree has Error!" << std::endl;
        }

        return quadTree;
    }
    virtual void simulateStep(AccelerationStructure * accel, std::vector<Particle> & particles, std::vector<Particle> & newParticles, StepParameters params) override
    {
        // TODO: implement sequential version of quad-tree accelerated n-body simulation here,
        // using quadTree as acceleration structure
        auto quadTree = dynamic_cast<QuadTree*>(accel);  // 修正1

        for (size_t i = 0; i < particles.size(); i++) {
            auto &p = particles[i];
            std::vector<Particle> neighbors;
            quadTree->getParticles(neighbors, p.position, params.cullRadius);  // 修正2
            Vec2 force(0.0f, 0.0f);
            for (auto &q : neighbors) {
                if (p.id == q.id) continue;
                force += computeForce(p, q, params.cullRadius);
            }
            newParticles[i] = updateParticle(p, force, params.deltaTime);
        }

    }
};

std::unique_ptr<INBodySimulator> createSequentialNBodySimulator()
{
    return std::make_unique<SequentialNBodySimulator>();
}
