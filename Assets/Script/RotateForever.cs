using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateForever : MonoBehaviour
{

    public float speedUp = 0.5f;
    public float speedLeft = 0.5f;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        this.transform.Rotate(Vector3.up * speedUp);
        this.transform.Rotate(Vector3.left * speedLeft);
    }
}
