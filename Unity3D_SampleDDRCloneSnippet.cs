/**
Soft Dance Dance Revolution Inspired game in Unity3D 
Christopher Phyffer 2020
https://phyffer.com

This is a sample snippet of a game object (a beat) to be spawned at X time, animating iteslf from `startTarget`
to `endTarget` with a specified speed and goal key. 

Should the player complete this beat within a specified deadzone (located in another class), they will score a point.

**/

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Beat : MonoBehaviour
{
    private bool _initialized = false;
    private float _speed = 0f;
    private float _journeyLength = 0f;
    private float _currentJourneyTime = 0f;
    private float _lifespan= 0f;
    
    public Vector3 endTarget;
    public Vector3 startTarget;
    public float journeyDesiredTime = 0f;
    public char key = 'u';
    public MidiNote note;
    public ScoreManager scoreManager;
    public float acceptableMouseDeadzonePercent = 0f;

    public void Initialize(){
        // Grab the distance between the Goal and Spawner
        this.gameObject.transform.position = this.startTarget;
        this._journeyLength = Vector3.Distance(this.startTarget, this.endTarget);
        this._speed = this._journeyLength / this.journeyDesiredTime;
        this._initialized = true;
        print("Speed: " + this._speed.ToString() + " Journey Length: " + this._journeyLength.ToString() );
    }
    private void Update() {
        if(!this._initialized) {
            return;
        }
        this._currentJourneyTime += Time.deltaTime * this._speed;
        float journeyTraveledDistance = this._currentJourneyTime/this._journeyLength;
        this.gameObject.transform.position = Vector3.Lerp(this.startTarget, this.endTarget, journeyTraveledDistance);
        this._lifespan+= Time.deltaTime;
        //print(journeyTraveledDistance);
    }
    private void OnMouseDown() {
        this.doHit();
    }
    public void DestroyBeat(bool success) {
        print("_lifespan: " + this._lifespan.ToString());
        Destroy(this.gameObject);
    }
    public void setNote(MidiNote note) {
        this.note = note;
    }
    public void doHit() {
        float journeyTraveledDistance = this._currentJourneyTime/this._journeyLength;
        float max = 1 + this.acceptableMouseDeadzonePercent;
        float min = 1 - this.acceptableMouseDeadzonePercent;
        print("Travel Dist: " + journeyTraveledDistance.ToString() + " Min: " + min.ToString() + " Max: " + max.ToString() );
        if(max >= journeyTraveledDistance && min <= journeyTraveledDistance) {
            this.note.isHit = true;
            this.scoreManager.updateScore(1);
            this.DestroyBeat(true);
        }
    }
}