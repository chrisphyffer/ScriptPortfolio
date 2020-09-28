/**
Sample Script for Motion Capture System in Unity3D
Developed by Christopher Phyffer 2020
https://phyffer.com

This base parent script allows a user to utilize their Vive motion capture, it can perform the following:
+ Record position and rotation of Vive Tracker data and export into an FBX using a plugin (like SceneTrack)
+ Output the position and rotation of Vive trackers Live into any program that accepts the OSC protocol (for example, to keyframe incoming data in your DCC)
+ Record the position and rotation of a Unity3D Humanoid Mannequin's Bones for retargeting in any DCC such as Blender, Maya, and Max.
+ Save Motion Capture presets so any actor can load the configuration of any character's joint position data in Json. File is specified as:
    {ACTOR_NAME}_{CHARACTER_NAME}_Presets.json

Note ALL incoming and outgoing rotations are handled using the Quaternion system. Failure to set the rotation space to Quaternion in your DCC
will result in frequent Gimbal lock, and generate inaccurate rotations. Euler rotations are inaccurate for keyframing even
though the DCC does it's best to compensate for this.

**/

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Animations;
using System.Text;

using RootMotion.FinalIK;
using System.IO;

using Valve.VR;
using Valve.VR.InteractionSystem;

namespace Phyffer
{
    public class PhyfferAvatar : PhyfferPuppet
    {
        [Header("Phyffer Avatar System Main Settings")]

        [Tooltip("Are we using FinalIK VRIK?")]
        public bool usingFinalIK = true;

        [Tooltip("Our Avatars name, used as the JSON preset Prefix and in the OSC.")]
        public string characterName = "GenericAvatar";

        [Tooltip("Update our VR Building Stages Manually by pressing this button.")]
        public bool manuallyUpdatedStage = false;

        [Tooltip("The name of the person controlling our avatar as an ENUM, located in PhyfferEnums.AvatarOperator")]
        public AvatarOperator avatarOperator;

        [Header("Steam Controller Bindings")]

        public SteamVR_Action_Pose m_ActionPose;



        [Tooltip("Puppet String Settings - Controls how the Puppet Strings work as you manipulate them.")]


        [Header("Avatar Control Settings")]
        public PuppetStringSettings puppetStringSettings;
        public List<TrackedObject> trackedObjects = new List<TrackedObject>();


        [Header("Mannequin Settings")]
        public PuppetMasterRigControl mannequinRigParent;
        public MannequinDisplaySettings MannequinDisplaySettings;


        //[Header("VR Data from Steam")]
        //public Camera VRCamera;
        protected PuppetMasterHand leftHandMaster;
        protected PuppetMasterHand rightHandMaster;
        protected int stage = 0;

        protected string configurationfile = "";

        const string VRTRACKER_NAME_PREFIX = "VRTracker_";
        const string PUPPET_NAME_PREFIX = "PuppetString_";
        protected Player _player;


        [Tooltip("The VR Controller button that will update our Stages. Activates on Left Hand Only.")]
        public SteamVR_Action_Boolean increaseStage = SteamVR_Input.GetAction<SteamVR_Action_Boolean>("CallMenu");

        public SteamVR_Action_Boolean hideTrackersAction = SteamVR_Input.GetAction<SteamVR_Action_Boolean>("HideTrackers");

        protected void Start()
        {
            base.Start();
            _player = Player.instance;

            // Because the Player is INHABITING THE BODY of this Avatar, we want to destroy
            // The MannequinRigParent. The mannequinRigParent is only used for Puppets that we only
            // Have Distant Control Over.
            if (mannequinRigParent)
            {
                Debug.Log(((string)mannequinRigParent.gameObject.name) + "Destroy");
                Destroy(mannequinRigParent);
            }
        }

        private bool trackersHidden = false;
        protected void Update() {
            if (!usingFinalIK)
            {
                if (increaseStage.GetStateUp(SteamVR_Input_Sources.RightHand) || increaseStage.GetStateUp(SteamVR_Input_Sources.LeftHand) 
                        || manuallyUpdatedStage)
                {
                    manuallyUpdatedStage = false;

                    this.InitializeHands();
                    buildTrackerAndStrings();
                    if (enableOSC)
                    {
                        buildOSCPuppet();
                    }

                    AssignTrackers();
                    AssignPuppetStringsToTrackers();

                    if (enableOSC)
                    {
                        CalibrateOSCPuppet();
                    }
                }
            }
            if (hideTrackersAction.GetStateUp(SteamVR_Input_Sources.RightHand) || 
            hideTrackersAction.GetStateUp(SteamVR_Input_Sources.LeftHand))
            {
                ToggleTrackers();
            }
        }

        public void ToggleTrackers() {
            foreach(TrackedObject tracker in trackedObjects){
                //
            }
            trackersHidden = !trackersHidden;
        }

        public void AssignPuppetStringsToTrackers()
        {
            foreach (TrackedObject tracker in trackedObjects)
            {
                if (!tracker.vrTrackerGameObject)
                {
                    continue;
                }
                if (tracker.trackerType == TrackerType.Other && tracker.vrTrackerGameObject.GetComponent<SteamVR_TrackedObject>().index == SteamVR_TrackedObject.EIndex.None)
                {
                    continue;
                }
                tracker.puppetStringGameObject.transform.SetParent(tracker.vrTrackerGameObject.transform);
            }
        }

        ///<summary> Build out our OSC Objects. Will Parent Constrain these to the puppetstring in
        ///the CalibrateOSCPuppetSection.</summary>
        public void buildOSCPuppet()
        {
            print("Building OSC Objects and setting OSC data.");
            foreach (TrackedObject tracker in trackedObjects)
            {
                if (!tracker.puppetStringGameObject)
                {
                    continue;
                }
                print("Building OSC Tracking object for Tracker: " + tracker.name);
                GameObject oscTransmitterObject = new GameObject("OSCTransmitter_" + tracker.name);

                //oscTransmitterObject.transform.parent = mannequinRigParent.gameObject.transform;
                oscTransmitterObject.transform.parent = gameObject.transform;

                oscTransmitterObject.transform.localScale = new Vector3(.1f, .1f, .1f);
                PhyfferOSCTrackedObject osc_object_component = oscTransmitterObject.AddComponent<PhyfferOSCTrackedObject>();
                osc_object_component.osc = oscScript;
                osc_object_component.oscAddressDestination = "/MocapOut/" + tracker.name;
                osc_object_component.oscAddressListening = "/MocapInput/" + tracker.name;

                osc_object_component.oscDirection = oscDirection;
                osc_object_component.oscId = tracker.oscIdx;
                osc_object_component.displayMesh = MannequinDisplaySettings.displayMesh;
                osc_object_component.displayMeshMaterial = MannequinDisplaySettings.displayMeshMaterial;
                osc_object_component.PuppetStringObject = tracker.puppetStringGameObject;
            }

            // Test Ping 

            OscMessage message = new OscMessage();
            message.address = "/OSCPING";
            // Build our Quaternion : (Blender => Unity ) w = -y, x => x, y => -z, z => w
            message.values.Add(0);
            message.values.Add(1);
            message.values.Add(0);
            message.values.Add(0);
            message.values.Add(0);

            // Send a simple Ping
            print(oscScript);
            oscScript.Send(message);
            Debug.Log("Ping");
        }

        ///<summary>Parent constrain our OSC Objects to the puppetstrings.</summary>
        public void CalibrateOSCPuppet()
        {
            print("Calibrating OSC to Blender Mannequin.");
            foreach (PhyfferOSCTrackedObject oscTransmitterObject in FindObjectsOfType<PhyfferOSCTrackedObject>())
            {
                ParentConstraint pconstraint = oscTransmitterObject.gameObject.AddComponent<ParentConstraint>();
                ConstraintSource cons = new ConstraintSource();

                // If this puppet string is not available (for example, a vive tracker is not turned on)
                if (!oscTransmitterObject.PuppetStringObject)
                {
                    continue;
                }

                cons.sourceTransform = oscTransmitterObject.PuppetStringObject.transform;
                cons.weight = 1f;
                pconstraint.AddSource(cons);

                pconstraint.translationAtRest = oscTransmitterObject.transform.position;
                pconstraint.rotationAtRest = oscTransmitterObject.transform.rotation.eulerAngles;
                pconstraint.locked = true;
                pconstraint.constraintActive = true;

                oscTransmitterObject.oscDirection = OSCDirections.Send;
                Destroy(oscTransmitterObject.gameObject.GetComponent<MeshRenderer>());
            }
        }



        ///<summary>Adds the <c>PuppetMasterHand</c> component to all our VR hands, as well as 
        /// setting up some essential GameObjects enabling our hands to
        /// puppet any object with the <c>PuppetMasterString</c> component.</summary>
        protected void InitializeHands()
        {
            if(_player) {
                print("Initializing Hands.");
                foreach (Hand hand in _player.hands)
                {
                    if (hand.handType != SteamVR_Input_Sources.LeftHand && hand.handType != SteamVR_Input_Sources.RightHand)
                    {
                        continue;
                    }
                    GameObject puppetMasterHand = Instantiate(new GameObject());
                    puppetMasterHand.name = "Puppet Master Hand";
                    GameObject initialRotationOffset = Instantiate(new GameObject());
                    initialRotationOffset.name = "Initial Rotation Offset";

                    initialRotationOffset.transform.SetParent(puppetMasterHand.transform);

                    puppetMasterHand.AddComponent<PuppetMasterHand>();
                    puppetMasterHand.GetComponent<PuppetMasterHand>().parentHand = hand;
                    puppetMasterHand.GetComponent<PuppetMasterHand>().initialRotationOffset = initialRotationOffset;
                    puppetMasterHand.transform.SetParent(hand.transform);

                    if (hand.handType == SteamVR_Input_Sources.LeftHand)
                    {
                        this.leftHandMaster = puppetMasterHand.GetComponent<PuppetMasterHand>();
                        this.leftHandMaster.Activate();
                    }
                    else if (hand.handType == SteamVR_Input_Sources.RightHand)
                    {
                        this.rightHandMaster = puppetMasterHand.GetComponent<PuppetMasterHand>();
                        this.rightHandMaster.Activate();
                    }
                }
            } else {

            }

        }

        /// <summary>Instantiates all Tracker Objects as Game Objects
        /// Then adds the Puppet Strings components to them.</summary>
        protected void buildTrackerAndStrings()
        {
            print("BUILDING TRACKERS AND PUPPET STRINGS.");
            GameObject vrTrackersParent = new GameObject();
            vrTrackersParent.name = "VRTrackersParent";
            vrTrackersParent.transform.SetParent(this.gameObject.transform);

            foreach (TrackedObject tracker in trackedObjects)
            {
                print("BUILDING TRACKER : " + VRTRACKER_NAME_PREFIX + tracker.name);
                GameObject new_vr_tracker = new GameObject(VRTRACKER_NAME_PREFIX + tracker.name);
                //GameObject new_vr_tracker = tracker.vrTrackerPlaceholderObject;
                new_vr_tracker.name = VRTRACKER_NAME_PREFIX + tracker.name;
                new_vr_tracker.transform.SetParent(this.transform);

                GameObject new_puppetstring = new GameObject(PUPPET_NAME_PREFIX + tracker.name);
                new_puppetstring.transform.parent = new_vr_tracker.transform;

                new_vr_tracker.AddComponent<PhyfferGetVRPuppetData>();
                new_vr_tracker.GetComponent<PhyfferGetVRPuppetData>().deviceSerialNumber = tracker.serialNumber;
                new_vr_tracker.transform.parent = vrTrackersParent.transform;

                PuppetString puppetStringComponent = new_puppetstring.AddComponent<PuppetString>();
                puppetStringComponent.puppetStringName = tracker.name;
                puppetStringComponent.displayMesh = puppetStringSettings.displayMesh;
                puppetStringComponent.displayMeshMaterial = puppetStringSettings.displayMeshMaterial;
                puppetStringComponent.activeMat = puppetStringSettings.activeMaterial;
                puppetStringComponent.inactiveMat = puppetStringSettings.inactiveMaterial;
                puppetStringComponent.VRTracker = new_vr_tracker;

                new_vr_tracker.GetComponent<PhyfferGetVRPuppetData>().puppetStringTarget = new_puppetstring;
                new_vr_tracker.GetComponent<PhyfferGetVRPuppetData>().puppetStringOffset = new_puppetstring;

                if (tracker.trackerType == TrackerType.Head)
                {
                    new_vr_tracker.AddComponent<SteamVR_TrackedObject>();
                    new_vr_tracker.GetComponent<SteamVR_TrackedObject>().index = SteamVR_TrackedObject.EIndex.Hmd;
                }
                else if (tracker.trackerType == TrackerType.HandL || tracker.trackerType == TrackerType.HandR)
                {
                    new_vr_tracker.AddComponent<SteamVR_Behaviour_Pose>();
                    new_vr_tracker.GetComponent<SteamVR_Behaviour_Pose>().poseAction = m_ActionPose;

                    switch (tracker.trackerType)
                    {
                        case TrackerType.HandL:
                            new_vr_tracker.GetComponent<SteamVR_Behaviour_Pose>().inputSource = SteamVR_Input_Sources.LeftHand;
                            new_puppetstring.GetComponent<PuppetString>().selfHand = leftHandMaster.GetComponent<PuppetMasterHand>();
                            break;
                        case TrackerType.HandR:
                            new_vr_tracker.GetComponent<SteamVR_Behaviour_Pose>().inputSource = SteamVR_Input_Sources.RightHand;
                            new_puppetstring.GetComponent<PuppetString>().selfHand = rightHandMaster.GetComponent<PuppetMasterHand>();
                            break;
                    }
                }
                else
                {
                    print("Adding SteamVR_TrackedObject: " + VRTRACKER_NAME_PREFIX + tracker.name);
                    new_vr_tracker.AddComponent<SteamVR_TrackedObject>();
                }

                trackedObjects.Find(e => e == tracker).puppetStringGameObject = new_puppetstring;
                trackedObjects.Find(e => e == tracker).vrTrackerGameObject = new_vr_tracker;

                //Set our Scenetrack Object.
                //GameObject new_vr_tracker = tracker.vrTrackerPlaceholderObject;
            }
        }

        protected bool AssignTrackers()
        {
            Debug.Log("Assigning trackers()");

            //Find all tracker trackers with VR Puppet Data
            foreach (TrackedObject tracker in trackedObjects)
            {
                if (tracker.trackerType != TrackerType.Other)
                {
                    continue;
                }

                print("Assigning Tracker: " + tracker.name);

                bool foundActiveVRTracker = false;
                print(SteamVR.connected.ToString());
                for (int i = 0; i < SteamVR.connected.Length; ++i)
                {
                    if (SteamVR.connected[i])
                    {
                        uint index = (uint)i;
                        ETrackedPropertyError error = new ETrackedPropertyError();

                        StringBuilder sb = new StringBuilder();
                        OpenVR.System.GetStringTrackedDeviceProperty(index, ETrackedDeviceProperty.Prop_SerialNumber_String, sb, OpenVR.k_unMaxPropertyStringSize, ref error);
                        var probablyUniqueDeviceSerial = sb.ToString();
                        print("YAY CONNECTED: " + sb.ToString());

                        var deviceClass = OpenVR.System.GetTrackedDeviceClass((uint)i);

                        if (probablyUniqueDeviceSerial == tracker.serialNumber)
                        {
                            Debug.Log("Device " + i.ToString() + " is connected and Assigned: " + deviceClass + " | " + probablyUniqueDeviceSerial);
                            tracker.vrTrackerGameObject.GetComponent<SteamVR_TrackedObject>().index = (SteamVR_TrackedObject.EIndex)index;
                            foundActiveVRTracker = true;
                        }
                    }
                }
                if (!foundActiveVRTracker)
                {
                    Destroy(tracker.vrTrackerGameObject);
                    tracker.vrTrackerGameObject = null;
                }
            }

            return true;
        }

        protected void SaveJSON()
        {
            PhyfferSavePuppetOffsets save = SavePuppetOffsets();
            string json = JsonUtility.ToJson(save);

            File.WriteAllText(configurationfile, json);

            //BinaryFormatter bf = new BinaryFormatter();
            //FileStream file = File.Create(Application.persistentDataPath + "/gamesave.save");
            //bf.Serialize(file, save);
            //file.Close();

            Debug.Log("Saving as JSON: " + json);
        }

        protected const string SAVE_SEPARATOR = "#SAVE-VALUE#";
        protected void loadJSON()
        {
            if (File.Exists(configurationfile))
            {
                print(configurationfile);
                string saveString = File.ReadAllText(configurationfile);
                PhyfferSavePuppetOffsets loadedPuppetStringData = JsonUtility.FromJson<PhyfferSavePuppetOffsets>(saveString);

                foreach (PuppetOffsetSaveData puppetSave in loadedPuppetStringData.puppetOffsets)
                {
                    Debug.Log("LOADING DATA FOR ~~~~~~~~~~~~~~~~~~~~~" + puppetSave.name);
                    GameObject puppetStringObject = GameObject.Find(PUPPET_NAME_PREFIX + puppetSave.name);
                    puppetStringObject.transform.localPosition = puppetSave.position;
                    puppetStringObject.transform.localRotation = puppetSave.orientation;
                }

                Debug.Log("LOADED " + avatarOperator.ToString() + ":" + configurationfile + " Configuration for PuppetStrings");
            }
            else
            {
                Debug.LogWarning(configurationfile + ".json doesnt exist. Creating a new one.");
            }
        }

        protected PhyfferSavePuppetOffsets SavePuppetOffsets()
        {
            PhyfferSavePuppetOffsets savedOffsets = new PhyfferSavePuppetOffsets();

            foreach (TrackedObject trackedObject in trackedObjects)
            {
                if (trackedObject.puppetStringGameObject)
                {
                    PuppetOffsetSaveData puppetSave = new PuppetOffsetSaveData();
                    puppetSave.name = trackedObject.name;
                    puppetSave.orientation = trackedObject.puppetStringGameObject.transform.localRotation;
                    puppetSave.position = trackedObject.puppetStringGameObject.transform.localPosition;

                    Debug.Log(trackedObject.name);
                    savedOffsets.puppetOffsets.Add(puppetSave);
                    Debug.Log(savedOffsets.puppetOffsets);
                }
            }
            Debug.Log(savedOffsets);
            return savedOffsets;

        }
    }

}