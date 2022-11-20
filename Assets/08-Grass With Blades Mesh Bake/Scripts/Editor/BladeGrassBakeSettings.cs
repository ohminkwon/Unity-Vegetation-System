using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "BladeGrassMeshSettings", menuName = "MeshBake/BladeGrassMeshSettings")]
public class BladeGrassBakeSettings : ScriptableObject
{
    [Tooltip("The source mesh to build off of")]
    public Mesh sourceMesh;

    [Tooltip("The submesh index of the source mesh to use")]
    public int sourceSubMeshIndex;

    [Tooltip("A scale to apply to the source mesh before generating pyramids")]
    public Vector3 scale;

    [Tooltip("A rotation to apply to the source mesh before generating pyramids. Euler angles, in degrees")]
    public Vector3 rotation;

    [Tooltip("An offset to the random function used in the compute shader")]
    public Vector3 randomOffset;

    [Tooltip("The number of segments per blade. Will be clamped by the max value in the compute shader")]
    public int numBladeSegments;

    [Tooltip("The curveature shape of a grass blade")]
    public float curvature;

    [Tooltip("The maximum bend angle of a grass blade. In degrees.")]
    public float maxBendAngle;

    [Tooltip("Grass blade height")]
    public float height;

    [Tooltip("Grass blade height variance")]
    public float heightVariance;

    [Tooltip("Grass blade width")]
    public float width;

    [Tooltip("Grass blade width variance")]
    public float widthVariance;
}
