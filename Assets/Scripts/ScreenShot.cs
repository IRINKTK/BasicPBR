using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class ScreenShot : MonoBehaviour
{
    private void Capture()
    {
        ScreenCapture.CaptureScreenshot(Application.dataPath + "/Capture.png");
        Debug.LogError("CAPTURE!!!");
    }

    private void OnGUI()
    {
        if (GUI.Button(new Rect(Screen.width - 300, Screen.height - 100, Screen.width / 10, Screen.height / 20), "CAPTURE")) 
        { 
            Capture();
        }
    }
}
