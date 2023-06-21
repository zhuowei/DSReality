#include <RealityKit/RealityKit.h>

// https://developer.apple.com/videos/play/wwdc2021/10075/

using namespace metal;

[[visible]]
void boundedSurface(realitykit::surface_parameters params)
{
    constexpr sampler bilinear(filter::linear);

    auto tex = params.textures();
    auto surface = params.surface();
    auto material = params.material_constants();

    // USD textures have an inverse y orientation.
    float2 uv = params.geometry().uv0();
    uv.y = 1.0 - uv.y;
  
    // zhuowei: just base color
    half3 blendedColor = tex.base_color().sample(bilinear, uv).rgb;
    blendedColor *= half3(material.base_color_tint());
    
    // Set on the surface.
    surface.set_base_color(blendedColor);

    // Sample the normal and unpack.
    half3 texNormal = tex.normal().sample(bilinear, uv).rgb;
    half3 normal = realitykit::unpack_normal(texNormal);

    // Set on the surface.
    surface.set_normal(float3(normal));

    // Sample material textures.
    half roughness = tex.roughness().sample(bilinear, uv).r;
    half metallic = tex.metallic().sample(bilinear, uv).r;
    half ao = tex.ambient_occlusion().sample(bilinear, uv).r;
    half specular = tex.roughness().sample(bilinear, uv).r;

    // Apply material scaling factors.
    roughness *= material.roughness_scale();
    metallic *= material.metallic_scale();
    specular *= material.specular_scale();

    // Set material properties on the surface.
    surface.set_roughness(roughness);
    surface.set_metallic(metallic);
    surface.set_ambient_occlusion(ao);
    surface.set_specular(specular);

    // https://mastodon.art/@noah/110574749502309331
    // make everything outside of a pyramid-shaped box around origin transparent.
    float3 model_position = params.geometry().model_position();
    float3 divided_position = model_position / (0.04*-model_position.z);
    float3 divided_position_abs = abs(divided_position);
    if (divided_position_abs.x > 20 || divided_position_abs.y > 20 || -model_position.z < 0 || -model_position.z > 150) {
        // Yes, I know this is bad for performance
        discard_fragment();
    }
}
