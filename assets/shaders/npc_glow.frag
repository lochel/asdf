#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float u_time;
uniform float u_body_progress;

uniform float u_flicker_offset;
uniform float u_tint_offset;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    float t = u_time;
    float wave = u_body_progress * 8.0;
    float pulse = sin(t * 6.0 + wave + u_tint_offset) * 0.15 + 0.85;
    float flicker = sin(t * 20.0 + u_flicker_offset) * 0.05 + 0.95;
    vec3 evilTint = vec3(1.2, 0.6, 0.6);
    vec3 color = texelColor.rgb * pulse * flicker * evilTint;
    color = mix(color, color * color, 0.2);
    finalColor = vec4(color, texelColor.a) * fragColor * colDiffuse;
}
