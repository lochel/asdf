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
    vec3 base = texelColor.rgb;

    vec2 pos = gl_FragCoord.xy;
    float t = u_time * 0.15;

    float wave = sin(pos.x * 0.012 + pos.y * 0.015 + t) * 0.035;
    wave += sin(pos.y * 0.018 - t * 0.25) * 0.025;

    float dapple = sin(pos.x * 0.03 + pos.y * 0.025 + t * 0.4) * 0.025;
    dapple = max(0.0, dapple);

    float grain = sin(pos.x * 0.007 - pos.y * 0.009) * 0.015;

    float gx = floor(pos.x / 50.0);
    float gy = floor((pos.y - 100.0) / 50.0);
    float check = mod(gx + gy, 2.0);
    check = (check - 0.5) * 0.04;

    vec3 grassColor = base + vec3(wave + dapple + grain + check, wave * 0.35, check * 0.3);
    grassColor = clamp(grassColor, 0.0, 1.0);

    finalColor = vec4(grassColor, texelColor.a) * fragColor * colDiffuse;
}
