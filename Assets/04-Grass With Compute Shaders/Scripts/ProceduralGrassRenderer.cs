using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode] // This allows the grass renderer to be visible in edit mode
public class ProceduralGrassRenderer : MonoBehaviour
{
    [Tooltip("A mesh to extrude the grass from")]
    [SerializeField] private Mesh sourceMesh = default;

    [Tooltip("The grass geometry creating compute shader")]
    [SerializeField] private ComputeShader grassComputeShader = default;

    [Tooltip("The triangle count adjustment compute shader")]
    [SerializeField] private ComputeShader triToVertComputeShader = default;

    [Tooltip("The material to render the grass mesh")]
    [SerializeField] private Material material = default;

    [SerializeField] private GrassSettings grassSettings = default;

    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    private struct SourceVertex
    {
        public Vector3 position;
        public Vector3 normal;
        public Vector2 uv;
    }

    // A state variable to help keep track of whether compute buffers have been set up
    private bool initialized;
    // A compute buffer to hold vertex data of the source mesh
    private ComputeBuffer sourceVertBuffer;
    // A compute buffer to hold index data of the source mesh
    private ComputeBuffer sourceTriBuffer;
    // A compute buffer to hold vertex data of the generated mesh
    private ComputeBuffer drawBuffer;
    // A compute buffer to hold indirect draw arguments
    private ComputeBuffer argsBuffer;

    private ComputeShader instantiatedGrassComputeShader;
    private ComputeShader instantiatedTriToVertComputeShader;
    private Material instantiatedMaterial;

    // The id of the kernel in the pyramid compute shader
    private int idGrassKernel;
    // The id of the kernel in the tri to vert count compute shader
    private int idTriToVertKernel;
    // The x dispatch size for the pyramid compute shader
    private int dispatchSize;
    // The local bounds of the generated mesh
    private Bounds localBounds;

    // The size of one entry into the various compute buffers
    private const int SOURCE_VERT_STRIDE = sizeof(float) * (3 + 3 + 2); // position + normal + UV
    private const int SOURCE_TRI_STRIDE = sizeof(int);
    private const int DRAW_STRIDE = sizeof(float) * (2 + (3 + 3 + 2) * 3); // height + 3 * (position + normal + UV)
    private const int ARGS_STRIDE = sizeof(int) * 4;

    private void OnEnable()
    {
        // If initialized, call on disable to clean things up
        if (initialized)
        {
            OnDisable();
        }
        initialized = true;

        // Instantiate the shaders so they can point to their own buffers
        instantiatedGrassComputeShader = Instantiate(grassComputeShader);
        instantiatedTriToVertComputeShader = Instantiate(triToVertComputeShader);
        instantiatedMaterial = Instantiate(material);

        // Grab data from the source mesh
        Vector3[] positions = sourceMesh.vertices;
        Vector3[] normals = sourceMesh.normals;
        Vector2[] uvs = sourceMesh.uv;
        int[] tris = sourceMesh.triangles;

        // Create the data to upload to the source vert buffer
        SourceVertex[] vertices = new SourceVertex[positions.Length];
        for (int i = 0; i < vertices.Length; i++)
        {
            vertices[i] = new SourceVertex()
            {
                position = positions[i],
                normal = normals[i],
                uv = uvs[i],
            };
        }
        int numTriangles = tris.Length / 3; // The number of triangles in the source mesh is the index array / 3

        // Create compute buffers
        // The stride is the size, in bytes, each object in the buffer takes up
        sourceVertBuffer = new ComputeBuffer(vertices.Length, SOURCE_VERT_STRIDE, ComputeBufferType.Structured, ComputeBufferMode.Immutable);
        sourceVertBuffer.SetData(vertices);

        sourceTriBuffer = new ComputeBuffer(tris.Length, SOURCE_TRI_STRIDE, ComputeBufferType.Structured, ComputeBufferMode.Immutable);
        sourceTriBuffer.SetData(tris);
      
        drawBuffer = new ComputeBuffer(numTriangles * grassSettings.maxLayers, DRAW_STRIDE, ComputeBufferType.Append);
        drawBuffer.SetCounterValue(0); // Set the count to zero

        argsBuffer = new ComputeBuffer(1, ARGS_STRIDE, ComputeBufferType.IndirectArguments);
        // The data in the args buffer corresponds to:
        // 0: vertex count per draw instance. We will only use one instance
        // 1: instance count. One
        // 2: start vertex location if using a Graphics Buffer
        // 3: and start instance location if using a Graphics Buffer
        argsBuffer.SetData(new int[] { 0, 1, 0, 0 });

        // Cache the kernel IDs we will be dispatching
        idGrassKernel = grassComputeShader.FindKernel("Main");
        idTriToVertKernel = triToVertComputeShader.FindKernel("Main");

        // Set data on the shaders
        instantiatedGrassComputeShader.SetBuffer(idGrassKernel, "_SourceVertices", sourceVertBuffer);
        instantiatedGrassComputeShader.SetBuffer(idGrassKernel, "_SourceTriangles", sourceTriBuffer);
        instantiatedGrassComputeShader.SetBuffer(idGrassKernel, "_DrawTriangles", drawBuffer);
        instantiatedGrassComputeShader.SetInt("_NumSourceTriangles", numTriangles);
        instantiatedGrassComputeShader.SetInt("_MaxLayers", grassSettings.maxLayers);
        instantiatedGrassComputeShader.SetFloat("_TotalHeight", grassSettings.grassHeight);
        instantiatedGrassComputeShader.SetFloat("_CameraDistanceMin", grassSettings.lodMinCameraDistance);
        instantiatedGrassComputeShader.SetFloat("_CameraDistanceMax", grassSettings.lodMaxCameraDistance);
        instantiatedGrassComputeShader.SetFloat("_CameraDistanceFactor", Mathf.Max(0, grassSettings.lodFactor));
        instantiatedGrassComputeShader.SetFloat("_WorldPositionToUVScale", grassSettings.worldPositionUVScale);
        if (grassSettings.useWorldPositionAsUV)
        {
            instantiatedGrassComputeShader.EnableKeyword("USE_WORLD_POSITION_AS_UV");
        }

        instantiatedTriToVertComputeShader.SetBuffer(idTriToVertKernel, "_IndirectArgsBuffer", argsBuffer);

        instantiatedMaterial.SetBuffer("_DrawTriangles", drawBuffer);

        // Calculate the number of threads to use. Get the thread size from the kernel
        // Then, divide the number of triangles by that size
        grassComputeShader.GetKernelThreadGroupSizes(idGrassKernel, out uint threadGroupSize, out _, out _);
        dispatchSize = Mathf.CeilToInt((float)numTriangles / threadGroupSize);

        // Get the bounds of the source mesh and then expand by the pyramid height
        localBounds = sourceMesh.bounds;
        localBounds.Expand(grassSettings.grassHeight);
    }

    private void OnDisable()
    {
        // Dispose of buffers and copied shaders here
        if (initialized)
        {
            // If the application is not in play mode, we have to call DestroyImmediate
            if (Application.isPlaying)
            {
                Destroy(instantiatedGrassComputeShader);
                Destroy(instantiatedTriToVertComputeShader);
                Destroy(instantiatedMaterial);
            }
            else
            {
                DestroyImmediate(instantiatedGrassComputeShader);
                DestroyImmediate(instantiatedTriToVertComputeShader);
                DestroyImmediate(instantiatedMaterial);
            }

            // Release each buffer
            sourceVertBuffer.Release();
            sourceTriBuffer.Release();
            drawBuffer.Release();
            argsBuffer.Release();
        }
        initialized = false;
    }

    public Bounds TransformBounds(Bounds boundsOS)
    {
        var center = transform.TransformPoint(boundsOS.center);

        // transform the local extents' axes
        var extents = boundsOS.extents;
        var axisX = transform.TransformVector(extents.x, 0, 0);
        var axisY = transform.TransformVector(0, extents.y, 0);
        var axisZ = transform.TransformVector(0, 0, extents.z);

        // sum their absolute value to get the world extents
        extents.x = Mathf.Abs(axisX.x) + Mathf.Abs(axisY.x) + Mathf.Abs(axisZ.x);
        extents.y = Mathf.Abs(axisX.y) + Mathf.Abs(axisY.y) + Mathf.Abs(axisZ.y);
        extents.z = Mathf.Abs(axisX.z) + Mathf.Abs(axisY.z) + Mathf.Abs(axisZ.z);

        return new Bounds { center = center, extents = extents };
    }

    private void LateUpdate()
    {
        if(Application.isPlaying == false)
        {
            OnDisable();
            OnEnable();
        }

        // Clear the draw buffer of last frame's data
        drawBuffer.SetCounterValue(0);

        // Transform the bounds to world space
        Bounds bounds = TransformBounds(localBounds);

        // Update the shader with frame specific data
        instantiatedGrassComputeShader.SetMatrix("_LocalToWorld", transform.localToWorldMatrix);
        instantiatedGrassComputeShader.SetVector("_CameraPosition", Camera.main.transform.position);

        // Dispatch the pyramid shader. It will run on the GPU
        instantiatedGrassComputeShader.Dispatch(idGrassKernel, dispatchSize, 1, 1);

        // Copy the count (stack size) of the draw buffer to the args buffer, at byte position zero
        // This sets the vertex count for our draw procediral indirect call
        ComputeBuffer.CopyCount(drawBuffer, argsBuffer, 0);

        // This the compute shader outputs triangles, but the graphics shader needs the number of vertices,
        // we need to multiply the vertex count by three. We'll do this on the GPU with a compute shader 
        // so we don't have to transfer data back to the CPU
        instantiatedTriToVertComputeShader.Dispatch(idTriToVertKernel, 1, 1, 1);

        // DrawProceduralIndirect queues a draw call up for our generated mesh
        // It will receive a shadow casting pass, like normal
        Graphics.DrawProceduralIndirect(instantiatedMaterial, bounds, MeshTopology.Triangles, argsBuffer, 0,
            null, null, ShadowCastingMode.Off, true, gameObject.layer);
    }

}

[System.Serializable]
public class GrassSettings 
{
    [Tooltip("The total height of the grass layer stack")]
    public float grassHeight = 0.5f;
    
    [Tooltip("The maximum number of layers")]
    public int maxLayers = 16;

    [Tooltip("Level-of-detail settings. As the camera moves away, the shader will decrease the number of layers.\n" +
         "This is the distance from the camera LOD will start to take effect")]
    public float lodMinCameraDistance = 1f;

    [Tooltip("Level-of-detail settings. As the camera moves away, the shader will decrease the number of layers.\n" + 
        "This is the distance from the camera the grass will have the fewest possible layers")]
    public float lodMaxCameraDistance = 1f;

    [Tooltip("Level-of-detail settings. As the camera moves away, the shader will decrease the number of layers.\n" + 
        "This is a power applied to the distance lerp to control layer falloff")]
    public float lodFactor = 2f;

    [Tooltip("Use world position XZ as the UV. Useful for tiling")]
    public bool useWorldPositionAsUV;

    [Tooltip("Multiplier on world position when using it as a UV")]
    public float worldPositionUVScale;
}

