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
    float t = u_time;
    float pulse = sin(t * 8.0) * 0.1 + 0.9;
    vec3 color = texelColor.rgb * pulse;
    finalColor = vec4(color, texelColor.a) * fragColor * colDiffuse;
}
