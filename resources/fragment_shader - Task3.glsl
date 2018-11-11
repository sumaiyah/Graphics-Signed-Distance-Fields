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

float sphere(vec3 pt) {
  return length(pt) - 1;
}

float planeSDF(vec3 samplePoint){
    // plane at Y = -1
    // all points move back -1 (= +1)in y direction
    return (samplePoint.y + 1);
}

float intersectSDF(float distA, float distB) {
    return max(distA, distB);
}

float unionSDF(float distA, float distB) {
    return min(distA, distB);
}

float differenceSDF(float distA, float distB) {
    return max(distA, -distB);
}

float blendSDF(float a, float b) {
 float k = 0.2;
 float h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1);

 return mix(b, a, h) - k * h * (1 - h);
}

float oldSceneSDF(vec3 samplePoint) {

    // SDF of each shape and their mixed shapes
      float d, d1, d2, d3, d4,
       s1, s2, s3, s4,
       unionVal, intersectVal, differenceVal, blendVal;

    // Positions of the 4 cubes and spheres
      vec3 cube1 = vec3(-3, 0, -3);
      vec3 cube2 = vec3(3, 0, -3);
      vec3 cube3 = vec3(-3, 0, 3);
      vec3 cube4 = vec3(3, 0, 3);

      vec3 sphere1 = vec3(-2, 0, -2);
      vec3 sphere2 = vec3(4, 0, -2);
      vec3 sphere3 = vec3(-2, 0, 4);
      vec3 sphere4 = vec3(4, 0, 4);

      // samplePoint-cube = place cube correctly in scene
      d1 = cube((samplePoint-cube1));
      d2 = cube((samplePoint-cube2));
      d3 = cube((samplePoint-cube3));
      d4 = cube((samplePoint-cube4));

      s1 = sphere((samplePoint-sphere1));
      s2 = sphere((samplePoint-sphere2));
      s3 = sphere((samplePoint-sphere3));
      s4 = sphere((samplePoint-sphere4));

      unionVal = unionSDF(d1, s1);
      differenceVal = differenceSDF(d2, s2);
      blendVal = blendSDF(d3, s3);
      intersectVal = intersectSDF(d4, s4);

      // d = min of all distances = max distance along ray that point can safely move
      d = min4(unionVal, intersectVal, differenceVal, blendVal);
    return d;
}

float sceneSDF(vec3 samplePoint) {

    // SDF of each shape and their mixed shapes
      float d, d1, d2, d3, d4,
       s1, s2, s3, s4,
       unionVal, intersectVal, differenceVal, blendVal;

    // Positions of the 4 cubes and spheres
      vec3 cube1 = vec3(-3, 0, -3);
      vec3 cube2 = vec3(3, 0, -3);
      vec3 cube3 = vec3(-3, 0, 3);
      vec3 cube4 = vec3(3, 0, 3);

      vec3 sphere1 = vec3(-2, 0, -2);
      vec3 sphere2 = vec3(4, 0, -2);
      vec3 sphere3 = vec3(-2, 0, 4);
      vec3 sphere4 = vec3(4, 0, 4);

      // samplePoint-cube = place cube correctly in scene
      d1 = cube((samplePoint-cube1));
      d2 = cube((samplePoint-cube2));
      d3 = cube((samplePoint-cube3));
      d4 = cube((samplePoint-cube4));

      s1 = sphere((samplePoint-sphere1));
      s2 = sphere((samplePoint-sphere2));
      s3 = sphere((samplePoint-sphere3));
      s4 = sphere((samplePoint-sphere4));

      unionVal = unionSDF(d1, s1);
      differenceVal = differenceSDF(d2, s2);
      blendVal = blendSDF(d3, s3);
      intersectVal = intersectSDF(d4, s4);

      // d = min of all distances = max distance along ray that point can safely move
      d = min4(unionVal, intersectVal, differenceVal, blendVal);
      d = min(d, planeSDF(samplePoint));
    return d;
}

vec3 getNormal(vec3 pt) {
  return normalize(GRADIENT(pt, sceneSDF));}

vec3 getColor(vec3 pt) {
  vec3 colourA = vec3(0.4, 0.4, 1);
  vec3 colourB = (vec3(0.4, 1, 0.4));

  // if the point is in the plane - colour it else dont
  if (planeSDF(pt) <= CLOSE_ENOUGH){
        // finds distance from each point in the plane to the nearest object thats not in the plane
        float dist = oldSceneSDF(pt);
        float d = mod(dist, 1);
        float bound = mod(dist, 5);

        // every 5 units, draw ring of black 0.25 units wide
        if (bound > 4.75){
            return(vec3(0,0,0));
        }

        // else mix the colours in gradient
        return mix(colourB, colourA, d);
    }
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

