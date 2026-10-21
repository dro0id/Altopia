using UnityEngine;

/// <summary>Bloom + vignette + aberration chromatique (rendu Built-in, sans paquet externe). À poser sur la caméra.</summary>
[RequireComponent(typeof(Camera))]
public class SimpleBloom : MonoBehaviour
{
    public float threshold = 1.0f, intensity = 0.7f, vignette = 1.2f, aberration = 0.01f;
    public int iterations = 3;
    Material mat;

    void OnEnable() { var sh = Shader.Find("Altopia/Bloom"); if (sh != null) mat = new Material(sh); GetComponent<Camera>().allowHDR = true; }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if (mat == null) { Graphics.Blit(src, dst); return; }
        mat.SetFloat("_Threshold", threshold); mat.SetFloat("_Intensity", intensity); mat.SetFloat("_Vignette", vignette); mat.SetFloat("_Aberration", aberration);
        int w = Mathf.Max(2, src.width / 2), h = Mathf.Max(2, src.height / 2);
        var a = RenderTexture.GetTemporary(w, h, 0, src.format); var b = RenderTexture.GetTemporary(w, h, 0, src.format);
        Graphics.Blit(src, a, mat, 0);
        for (int i = 0; i < iterations; i++)
        {
            mat.SetVector("_Dir", new Vector4(1, 0, 0, 0)); Graphics.Blit(a, b, mat, 1);
            mat.SetVector("_Dir", new Vector4(0, 1, 0, 0)); Graphics.Blit(b, a, mat, 1);
        }
        mat.SetTexture("_BloomTex", a);
        Graphics.Blit(src, dst, mat, 2);
        RenderTexture.ReleaseTemporary(a); RenderTexture.ReleaseTemporary(b);
    }
}
