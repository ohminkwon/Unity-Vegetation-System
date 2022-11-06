using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GrassSpawner : MonoBehaviour
{
    [SerializeField] private GameObject grassPrefab = null;
    [SerializeField] private Settings settings = null;

    private void Start()
    {
        List<Vector2> spawnPoints = new List<Vector2>();

        var s = settings;

        Vector2 circleACenter = new Vector2(-s.areaHalfLength - s.circleCenterOffset, -s.areaHalfLength);
        Vector2 centerDelta = new Vector2(0, s.areaHalfLength * 2);
        float centerDistance = centerDelta.magnitude;
        Rect areaBounds = new Rect(-s.areaHalfLength, -s.areaHalfLength, s.areaHalfLength * 2, s.areaHalfLength * 2);

        // Loop through each ring
        for (int ringIndexA=0; ringIndexA < s.numRings; ringIndexA++)
        {
            for (int ringIndexB = 0; ringIndexB < s.numRings; ringIndexB++)
            {
                float radiusA = CalcRingRadius(ringIndexA, ringIndexB);
                float radiusB = CalcRingRadius(ringIndexB, ringIndexA);

                if(DoCirclesIntersect(centerDistance, radiusA, radiusB))
                {
                    Vector2 pointA = CalcIntersectionPoint(circleACenter, centerDelta, centerDistance, radiusA, radiusB);

                    if (IsPointInBounds(areaBounds, pointA))
                    {
                        spawnPoints.Add(pointA);
                    }
                }
            }
        }

        // Spawn the grass prefab at every determined point
        var centerPos = transform.position;
        foreach (var point in spawnPoints)
        {
            GameObject.Instantiate(grassPrefab, new Vector3(point.x, 0, point.y) + centerPos, Quaternion.Euler(0, Random.value*360, 0), transform);
        }
    }

    private float CalcRingRadius(int ringIndex, int otherCircleRingIndex)
    {
        return ringIndex * settings.ringRadiusIncrement + (otherCircleRingIndex % settings.staggerRingModulo == 0 ? settings.staggerRingOffset : 0);
    }
    private bool DoCirclesIntersect(float centerDistance, float radiusA, float radiusB)
    {
        return radiusA + radiusB > centerDistance && centerDistance > Mathf.Abs(radiusA - radiusB);
    }
    private Vector2 CalcIntersectionPoint(Vector2 circleACenter, Vector2 centerDelta, float centerDistance, float radiusA, float radiusB)
    {
        float lengthMultiplier = (radiusA * radiusA - radiusB * radiusB + centerDistance * centerDistance) / (2 * centerDistance);
        float heightMultiplier = Mathf.Sqrt(radiusA * radiusA - lengthMultiplier * lengthMultiplier);
        float lDivD = lengthMultiplier / centerDistance;
        float hDivD = heightMultiplier / centerDistance;

        Vector2 pointA = new Vector2(lDivD * centerDelta.x + hDivD*centerDelta.y + circleACenter.x,
                                    lDivD*centerDelta.y - hDivD*centerDelta.x + circleACenter.y);

        return pointA;
    }
    private bool IsPointInBounds(Rect areaBounds, Vector2 point)
    {
        return areaBounds.Contains(point);
    }

}

[System.Serializable]
public class Settings
{
    public int areaHalfLength;
    public int numRings;
    public float ringRadiusIncrement;
    public int staggerRingModulo;
    public float staggerRingOffset;
    public float circleCenterOffset;
}
