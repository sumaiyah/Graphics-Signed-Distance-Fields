#version 330

uniform vec2 resolution;
uniform float currentTime;
uniform vec3 camPos;
uniform vec3 camDir;
uniform vec3 camUp;
uniform sampler2D tex;
uniform bool showStepDepth;

in vec3 pos;

out vec3 color;

#define PI 3.1415926535897932384626433832795
#define RENDER_DEPTH 800
#define CLOSE_ENOUGH 0.00001

#define BACKGROUND -1
#define BALL 0
#define BASE 1

#define GRADIENT(pt, func) vec3( \
    func(vec3(pt.x + 0.0001, pt.y, pt.z)) - func(vec3(pt.x - 0.0001, pt.y, pt.z)), \
    func(vec3(pt.x, pt.y + 0.0001, pt.z)) - func(vec3(pt.x, pt.y - 0.0001, pt.z)), \
    func(vec3(pt.x, pt.y, pt.z + 0.0001)) - func(vec3(pt.x, pt.y, pt.z - 0.0001)))

const vec3 LIGHT_POS[] = vec3[](vec3(5, 18, 10));

///////////////////////////////////////////////////////////////////////////////
// BACKGROUND
// RAY DIRECTION
vec3 getBackground(vec3 dir) {
  float u = 0.5 + atan(dir.z, -dir.x) / (2 * PI);
  float v = 0.5 - asin(dir.y) / PI;
  vec4 texColor = texture(tex, vec2(u, v));
  return texColor.rgb;
}

vec3 getRayDir() {
  vec3 xAxis = normalize(cross(camDir, camUp));
  return normalize(pos.x * (resolution.x / resolution.y) * xAxis + pos.y * camUp + 5 * camDir);
}

///////////////////////////////////////////////////////////////////////////////
// SHAPES
// Non - linear
//float cube(vec3 p) {
//return max(max(abs(p.x), abs(p.y)), abs(p.z)) - 1; // 1 = radius
//}
float min4(float f1, float f2, float f3, float f4){
    // returns minimum of 4 values
    float m;
    m = min(f1, f2);
    m = min(m, f3);
    m = min(m, f4);

    return m;
}

// Linear
float cube(vec3 p) {
vec3 d = abs(p) - vec3(1); // 1 = radius
return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float cuboid( vec3 p, vec3 b ){
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sphere(vec3 pt) {
  return length(pt) - 1;
}

float cone(vec3 p, vec2 c){
    float q = length(p.xy);
    return dot(c,vec2(q,p.z));
}

float torus( vec3 p, vec2 t) {
  // want in xy plane - perpendicular to the z axis
  vec2 q = vec2(length(p.xy)-t.x,p.z);
  return length(q)-t.y;
}


float intersectSDF(float distA, float distB) {
    // chunk of sphere that both overlap
    return max(distA, distB);
}

float unionSDF(float distA, float distB) {
    // join two shapes together
    return min(distA, distB);
}

float differenceSDF(float distA, float distB) {
    // cube with sphere missing
    return max(distA, -distB);
}

float blendSDF(float a, float b) {
 // blend method from lecture notes to smoothly join shapes
 float k = 0.2;
 float h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1);

 return mix(b, a, h) - k * h * (1 - h);
}

float planeSDF(vec3 samplePoint){
    // plane at Y = -1
    // all points move back -1 (= +1)in y direction
    return (samplePoint.y);
}

float dot2( in vec3 v ) { return dot(v,v); }


float twist( vec3 pt )
{
    float t = pt.y * PI;
    return cube(vec3(pt.x*cos(t) + pt.z*sin(t),
                    pt.y,
                    -pt.x*sin(t) + pt.z*cos(t))) / (2*sqrt(2));
}

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
    vec3 pa = p - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}

float sceneSDF(vec3 p) {
    float d;
    d = sdCapsule(vec3(p.x,p.y+sin(p.x),p.z), vec3(-PI,0,0), vec3(PI,0,0), 0.5);

    return d;


}

vec3 getNormal(vec3 pt) {
  return normalize(GRADIENT(pt, sceneSDF));}

vec3 getColor(vec3 pt) {
  return vec3(1);
}

///////////////////////////////////////////////////////////////////////////////
// SHADING AND ILLUMINATION
float shade(vec3 eye, vec3 pt, vec3 n) {
  float val = 0;

  val += 0.1;  // Ambient

  for (int i = 0; i < LIGHT_POS.length(); i++) {
    vec3 l = normalize(LIGHT_POS[i] - pt);
    val += max(dot(n, l), 0);
  }
  return val;
}

vec3 illuminate(vec3 camPos, vec3 rayDir, vec3 pt) {
  vec3 c, n;
  n = getNormal(pt);
  c = getColor(pt);
  return shade(camPos, pt, n) * c;
}

/////////////////////////////////////////////////////////////////////////////
// RAYMARCHING
vec3 raymarch(vec3 camPos, vec3 rayDir) {
  int step = 0;
  float t = 0;

  for (float d = 1000; step < RENDER_DEPTH && abs(d) > CLOSE_ENOUGH; t += abs(d)) {
      // Create an SDF for the whole scene
      d = sceneSDF(camPos + t * rayDir);
      step++;
    }

  if (step == RENDER_DEPTH) {
      return getBackground(rayDir);
    } else if (showStepDepth) {
      return vec3(float(step) / RENDER_DEPTH);
    } else {
      return illuminate(camPos, rayDir, camPos + t * rayDir);
    }
}

///////////////////////////////////////////////////////////////////////////////

void main() {
  color = raymarch(camPos, getRayDir());
}

