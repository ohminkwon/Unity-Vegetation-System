using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;

public class GrassTrampleObject : MonoBehaviour
{
    // [SerializeField] private ForwardRendererData rendererSettings = null;

    [SerializeField] private UniversalRendererData rendererSettings = null;

    private bool TryGetFeature(out GrassTrampleFeature feature)
    {
        feature = rendererSettings.rendererFeatures.OfType<GrassTrampleFeature>().FirstOrDefault();

        return feature != null;
    }

    private void OnEnable()
    {
        if(TryGetFeature(out var feature))
        {
            feature.AddTrackedTransform(transform);
        }
    }
    private void OnDisable()
    {
        if(TryGetFeature(out var feature))
        {
            feature.RemoveTrackedTransform(transform);
        }
    }
}
