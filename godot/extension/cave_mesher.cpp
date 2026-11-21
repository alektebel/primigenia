#include "cave_mesher.h"
#include "convert.h"
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

using namespace godot;

namespace {
constexpr float STEP = 0.4f;
constexpr float BUFFER = 0.6f;

uint32_t hash3(uint32_t seed, uint32_t x, uint32_t y, uint32_t z) {
    uint32_t h = seed ^ (x * 0x8da6b343u) ^ (y * 0xd8163841u) ^ (z * 0xcb1ab31fu);
    h ^= h >> 16;
    h *= 0x7feb352du;
    h ^= h >> 15;
    h *= 0x846ca68bu;
    return h ^ (h >> 16);
}

float smooth(float t) { return t*t*(3 - 2*t); }
float mix(float a, float b, float t) { return a + t*(b-a); }

float noise(uint32_t seed, Vector3 p) {
    int x = int(std::floor(p.x)), y = int(std::floor(p.y)), z = int(std::floor(p.z));
    float tx = smooth(p.x-x), ty = smooth(p.y-y), tz = smooth(p.z-z);
    float rows[2][2];
    for (int k = 0; k < 2; ++k) {
        for (int j = 0; j < 2; ++j) {
            float a = float(hash3(seed, x, y+j, z+k) >> 8);
            float b = float(hash3(seed, x+1, y+j, z+k) >> 8);
            rows[k][j] = mix(a,b,tx) / 16777216.f;
        }
    }
    return mix(mix(rows[0][0],rows[0][1],ty), mix(rows[1][0],rows[1][1],ty), tz);
}

struct Cave {
    uint32_t seed;
    float half, length, radius, mouth_half, mouth_height;
    Vector3 origin;
    Vector2 facing;

    Vector3 rotate(Vector3 p) const {
        return {-facing.y*p.x-facing.x*p.z, p.y, facing.x*p.x-facing.y*p.z};
    }

    // Positive in air. The first grid plane is the open entrance (u = 0).
    // Local axes are sideways, up from the sim floor, and into the passage.
    float field(Vector3 p) const {
        float chamber_u = length + radius;
        float radial = Vector2(p.x,p.z-chamber_u).length();
        float flare = smooth(std::clamp(1-p.z/4.f, 0.f, 1.f));
        float width = mix(half+BUFFER, mouth_half, flare);
        float side_fraction = std::min(1.f, std::abs(p.x)/width);
        float lip_roof = mouth_height - (mouth_height-3.f)*side_fraction*side_fraction;
        float passage = std::min({width-std::abs(p.x), chamber_u+BUFFER-p.z,
                                  mix(3.1f,lip_roof,flare)-p.y});
        float dome = 3.4f + 3.1f*std::max(0.f, 1-radial*radial/(radius*radius));
        float chamber = std::min(radius+BUFFER-radial, dome-p.y);
        float chimney = std::min(2.f-Vector2(p.x-radius*.34f,p.z-chamber_u).length(), 9.f-p.y);
        float air = std::max({passage, chamber, chimney});
        for (int side : {-1, 1}) {
            Vector3 q = p - Vector3(side*(half+1.3f),2.3f,length*(side<0 ? .42f : .85f));
            q.z *= .72f;
            air = std::max(air, 3.f-q.length());
        }
        float coarse = noise(seed, p*.29f);
        float fine = noise(seed^0xac17u, p*.79f);
        float expansion = .5f + 2.5f*(.69f*coarse+.31f*fine);
        // Pin the lip to its requested cross-section and cap the chimney at 9 m.
        // Limit the entrance even when a short passage places an alcove near it.
        float lip = std::min(mouth_half-std::abs(p.x), lip_roof-p.y) + 2.f*p.z;
        return std::min({p.y, 9.f-p.y, lip, air + expansion*(1-flare)});
    }
};

bool number(const Dictionary &d, const char *key, float fallback, float lo, float hi, float &out) {
    return cpore::to_float(d.get(key,fallback),out) && out >= lo && out <= hi;
}

bool read_cave(const Dictionary &d, Cave &c) {
    int64_t seed;
    if (!cpore::to_int(d.get("seed",1),0,UINT32_MAX,seed)) return false;
    c.seed = uint32_t(seed);
    if (!number(d,"half",4,1,12,c.half) || !number(d,"length",14,4,48,c.length) ||
        !number(d,"radius",10,3,24,c.radius) ||
        !number(d,"mouth_half",c.half+1.2f,c.half+BUFFER,18,c.mouth_half) ||
        !number(d,"mouth_height",4.4f,3,9,c.mouth_height) ||
        !number(d,"x",0,-65536,65536,c.origin.x) || !number(d,"z",0,-65536,65536,c.origin.z) ||
        !number(d,"floor",0,-65536,65536,c.origin.y) ||
        !number(d,"fx",0,-1,1,c.facing.x) || !number(d,"fz",1,-1,1,c.facing.y) ||
        std::abs(c.facing.length_squared()-1.f) > .001f) return false;
    c.facing.normalize();
    return true;
}

// Cyclic cube corners, followed by the four vertical edges. Each intersected
// face links two cube edges. Tracing these links gives the marching-cubes
// polygons without a 256-case table. Adjacent cells share the face decision.
constexpr int edges[12][2] = {{0,1},{1,2},{2,3},{3,0},{4,5},{5,6},{6,7},{7,4},{0,4},{1,5},{2,6},{3,7}};
constexpr int faces[6][4] = {{0,1,2,3},{4,5,6,7},{0,9,4,8},{1,10,5,9},{2,11,6,10},{3,8,7,11}};
constexpr int face_corners[6][4] = {{0,1,2,3},{4,5,6,7},{0,1,5,4},{1,2,6,5},{2,3,7,6},{3,0,4,7}};

struct Mesh {
    const Cave &c;
    PackedVector3Array vertices, normals, stalactites, down, wet, flowstone, wall_normals;
    PackedInt32Array indices;

    int vertex(Vector3 p, uint32_t key) {
        constexpr float e = .025f;
        const Vector3 dx(e,0,0), dy(0,e,0), dz(0,0,e);
        Vector3 n(c.field(p+dx)-c.field(p-dx), c.field(p+dy)-c.field(p-dy), c.field(p+dz)-c.field(p-dz));
        n = c.rotate(n.normalized());
        Vector3 world = c.origin+c.rotate(p);
        vertices.push_back(world);
        normals.push_back(n);
        uint32_t roll = hash3(c.seed,key,13,97) % 1000;
        if (n.y < -.72f && roll < 17*noise(c.seed^163u,p*.41f)) {
            stalactites.push_back(world);
            down.push_back(n);
        } else if (n.y > .98f && p.y < .01f && roll < 5) {
            wet.push_back(world);
        } else if (std::abs(n.y) < .28f && roll < 8) {
            flowstone.push_back(world);
            wall_normals.push_back(n);
        }
        return vertices.size()-1;
    }

    void triangle(int a, int b, int d) {
        Vector3 cross = (vertices[b]-vertices[a]).cross(vertices[d]-vertices[a]);
        if (cross.length_squared() == 0) return;
        indices.push_back(a);
        indices.push_back(b);
        indices.push_back(d);
    }
};

void polygonize(Mesh &mesh, const float value[8], const int vertex[12]) {
    int next[12];
    std::fill_n(next, 12, -1);
    for (int f = 0; f < 6; ++f) {
        int hits[4], count = 0;
        for (int i = 0; i < 4; ++i) {
            if (vertex[faces[f][i]] >= 0) hits[count++] = i;
        }
        // Follow the air boundary around this face. Opposite cells traverse
        // the same segment in opposite directions. Face zero is wound inward.
        auto link = [&](int a, int b) {
            if ((value[face_corners[f][a]] > 0) != (f == 0)) std::swap(a,b);
            next[faces[f][a]] = faces[f][b];
        };
        if (count == 2) link(hits[0], hits[1]);
        if (count == 4) {
            double sum = 0;
            for (int corner : face_corners[f]) sum += value[corner];
            int offset = ((sum > 0) == (value[face_corners[f][0]] > 0)) ? 0 : 1;
            link(offset, offset+1);
            link((offset+2)%4, (offset+3)%4);
        }
    }
    for (int start = 0; start < 12; ++start) {
        if (next[start] < 0) continue;
        int curr = next[start];
        next[start] = -1;
        while (curr != start) {
            int following = next[curr];
            if (following != start) mesh.triangle(vertex[start],vertex[curr],vertex[following]);
            next[curr] = -1;
            curr = following;
        }
    }
}

void march(Mesh &mesh) {
    const Cave &c = mesh.c;
    int side = int(std::ceil(std::max({c.mouth_half+4,c.half+9,c.radius+5})/STEP));
    int nx = 2*side+1, ny = 25, slab = nx*ny;
    int nz = int(std::ceil((c.length+2*c.radius+6)/STEP))+1;
    int offsets[8] = {0,1,nx+1,nx,slab,slab+1,slab+nx+1,slab+nx};
    std::vector<float> samples(slab*nz);
    std::vector<std::array<int,3>> cache(samples.size(), {-1,-1,-1});
    // Offset the lattice so the flat floor and chimney cap fall between layers.
    auto point = [&](int i) {
        return Vector3((i%nx-side+.13f)*STEP, ((i/nx)%ny-.43f)*STEP, (i/slab)*STEP);
    };
    for (int i = 0; i < slab*nz; ++i) samples[i] = c.field(point(i));
    for (int z = 0; z < nz-1; ++z) for (int y = 0; y < ny-1; ++y) for (int x = 0; x < nx-1; ++x) {
        int base = z*slab+y*nx+x;
        float value[8];
        int positive = 0;
        for (int k = 0; k < 8; ++k) {
            value[k] = samples[base+offsets[k]];
            positive += value[k] > 0;
        }
        if (positive == 0 || positive == 8) continue;
        int vertex[12];
        for (int e = 0; e < 12; ++e) {
            int a = edges[e][0], b = edges[e][1];
            vertex[e] = -1;
            if ((value[a]>0) == (value[b]>0)) continue;
            int i = base+offsets[a], j = base+offsets[b], stride = std::abs(i-j);
            int axis = stride == 1 ? 0 : stride == nx ? 1 : 2;
            int key = std::min(i,j);
            int &id = cache[key][axis];
            if (id < 0) id = mesh.vertex(point(i).lerp(point(j),value[a]/(value[a]-value[b])),3*key+axis);
            vertex[e] = id;
        }
        polygonize(mesh,value,vertex);
    }
}
}

Dictionary cpore::build_cave_mesh(const Dictionary &params) {
    Cave cave;
    if (!bool(params.get("enabled",true)) || !read_cave(params,cave)) return {};
    Mesh mesh{cave};
    march(mesh);
    Dictionary result;
    result["vertices"] = mesh.vertices;
    result["normals"] = mesh.normals;
    result["indices"] = mesh.indices;
    result["stalactites"] = mesh.stalactites;
    result["stalactite_normals"] = mesh.down;
    result["wet_patches"] = mesh.wet;
    result["flowstone"] = mesh.flowstone;
    result["flowstone_normals"] = mesh.wall_normals;
    return result;
}
