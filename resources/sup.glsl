float sceneSDF(vec3 samplePoint) {
    float d1, s1, t1, d2, intersectVal, intersectVal2;

    // d = min of all distances = max distance along ray that point can safely move
    vec3 sphere1 = vec3(0, 0, 0);
    s1 = sphere((samplePoint-sphere1));


    vec3 torus1 = vec3(1, 1, 1);
    t1 = torus((samplePoint-vec3(0, 0, 1)), vec2(0.3,0.3));

    float d = min(t1,s1);
    d = min(d, planeSDF(samplePoint));
    return d;
}

float planeSDF(vec3 samplePoint){
    // plane at Y = -1
    // all points move back -1 (= +1)in y direction
    return (samplePoint.y);
}