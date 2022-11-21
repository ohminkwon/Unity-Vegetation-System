using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(ShadowGrassBakeSettings))]
public class ShadowGrassBakeInspector : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        if (GUILayout.Button("Create"))
        {
            var shaderGUID = AssetDatabase.FindAssets("ShadowGrassMeshBuilder").FirstOrDefault();
            if (string.IsNullOrEmpty(shaderGUID))
            {
                Debug.LogError("Cannot find compute shader: ShadowGrassMeshBuilder.compute");
            }
            else
            {
                var shader = AssetDatabase.LoadAssetAtPath<ComputeShader>(AssetDatabase.GUIDToAssetPath(shaderGUID));

                // Opens a progress bar window
                EditorUtility.DisplayProgressBar("Building mesh", "", 0);

                // Run the baker
                var settings = serializedObject.targetObject as ShadowGrassBakeSettings;
                bool success = ShadowGrassBaker.Run(shader, settings, out var generatedMesh);

                EditorUtility.ClearProgressBar();

                if (success)
                {
                    SaveMesh(generatedMesh);
                    Debug.Log("Mesh saved successfully");
                }
                else
                {
                    Debug.LogError("Failed to create mesh");
                }
            }
        }
    }

    private void SaveMesh(Mesh mesh)
    {
        // Opens a file save dialog window
        string path = EditorUtility.SaveFilePanel("Save Mesh Asset", "Assets/", name, "asset");

        // Path is empty if the user exits out of the window
        if (string.IsNullOrEmpty(path))
        {
            return;
        }

        // Transforms the path to a full system path, to help minimize bugs
        path = FileUtil.GetProjectRelativePath(path);

        // Check if this path already contains a mesh
        // If yes, we want to replace that mesh with the baked mesh while keeping the same GUID,
        // so any other object using it will automatically update
        var oldMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
        if (oldMesh != null)
        {
            // Clear all mesh data on the old mesh, readying it to receive new data
            oldMesh.Clear();
            // Copy mesh data from the new mesh to the old mesh
            EditorUtility.CopySerialized(mesh, oldMesh);
        }
        else
        {
            // Nothing is at this path (or it wasn't a mesh), so create a new asset
            AssetDatabase.CreateAsset(mesh, path);
        }

        // Tell Unity to save all assets
        AssetDatabase.SaveAssets();
    }
}
