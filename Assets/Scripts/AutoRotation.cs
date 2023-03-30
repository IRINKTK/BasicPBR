using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AutoRotation : MonoBehaviour
{
    [Range(-3, 3)]
    public float RoataionSpeed = 0;
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Vector3 rotation = transform.rotation.eulerAngles;
        rotation += new Vector3(0, 0.5f, 0) * RoataionSpeed;
        transform.rotation = Quaternion.Euler(rotation);
    }
}
