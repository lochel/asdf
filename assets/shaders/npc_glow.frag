#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float u_time;
uniform float u_body_progress;
uniform vec2 u_body_pos;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    float t = u_time;
    float wave = u_body_progress * 8.0 + u_body_pos.y * 0.3 + u_body_pos.x * 0.2;
    float pulse = sin(t * 10.0 + wave) * 0.15 + 0.85;
    float flicker = sin(t * 27.3) * 0.05 + 0.95;
    vec3 evilTint = vec3(1.2, 0.6, 0.6);
    vec3 color = texelColor.rgb * pulse * flicker * evilTint;
    color = mix(color, color * color, 0.2);
    finalColor = vec4(color, texelColor.a) * fragColor * colDiffuse;
}
