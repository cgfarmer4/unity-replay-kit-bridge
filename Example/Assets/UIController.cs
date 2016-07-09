﻿using UnityEngine;
using System.Collections;

public class UIController : MonoBehaviour {

    // Use this for initialization
    void Start () {
    
    }
    
    // Update is called once per frame
    void Update () {
    
    }

    public void OnPressStartRecordingButton() {
        if (!ReplayKitBridge.IsScreenRecorderAvailable || ReplayKitBridge.IsRecording) {
            return;
        }

        // Set up delegates
        ReplayKitBridge.Instance.onStartRecordingCallback = OnStartRecording;
        ReplayKitBridge.Instance.onDiscardRecordingCallback = OnDiscardRecording;
        ReplayKitBridge.Instance.onStopRecordingCallback = OnStopRecording;
        ReplayKitBridge.Instance.onFinishPreviewCallback = OnFinishPreview;

        // Enable camera and microphone
        ReplayKitBridge.IsCameraEnabled = true;
        ReplayKitBridge.IsMicrophoneEnabled = true;

        // And then start recording
        ReplayKitBridge.StartRecording();
    }

    public void OnPressDiscardRecordingButton() {
        if (!ReplayKitBridge.IsRecording) {
            return;
        }

        // Disable camera and microphone
        ReplayKitBridge.IsCameraEnabled = false;
        ReplayKitBridge.IsMicrophoneEnabled = false;

        // Discard recording
        ReplayKitBridge.DiscardRecording();
    }

    public void OnPressStopRecordingButton() {
        if (!ReplayKitBridge.IsRecording) {
            return;
        }

        // Disable camera and microphone
        ReplayKitBridge.IsCameraEnabled = false;
        ReplayKitBridge.IsMicrophoneEnabled = false;

        // Stop recording
        ReplayKitBridge.StopRecording();
    }

    public void OnStartRecording() {
        Debug.Log("OnStartRecording");
    }

    public void OnDiscardRecording() {
        Debug.Log("OnDiscardRecording");
    }

    public void OnStopRecording() {
        Debug.Log("OnStopRecording");

        Time.timeScale = 0;
        ReplayKitBridge.PresentPreviewView();
    }

    public void OnFinishPreview(string activityType) {
        Debug.Log("OnFinishPreview activityType=" + activityType);
        
        ReplayKitBridge.DismissPreviewView();
        Time.timeScale = 1;
    }
}
