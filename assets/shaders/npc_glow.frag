#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float u_time;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);

    float dist = distance(fragTexCoord, vec2(0.5));
    float pulse = sin(u_time * 3.0) * 0.3 + 0.7;
    float aura = (1.0 - smoothstep(0.15, 0.5, dist)) * 0.25 * pulse;

    vec3 glow = vec3(aura, aura * 0.15, 0.0);
    vec3 color = texelColor.rgb + glow;
    color = clamp(color, 0.0, 1.0);

    finalColor = vec4(color, texelColor.a) * fragColor * colDiffuse;
}
