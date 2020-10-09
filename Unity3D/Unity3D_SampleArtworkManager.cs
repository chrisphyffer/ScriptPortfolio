/**
Sample Artwork Manager Snippet from a project in Unity3D
Christopher Phyffer 2020
https://phyffer.com

This script fetches and manages Artwork from a backend server, the process is as follows:
1.) Fetch the artwork image (jpeg, gif, png)
2.) Create a Texture with appropriate settings to house the image
3.) Set the texture to the material
4.) Instantiate an Artwork Image Prefab into the world and assign the material
5.) Set the artwork gameobject transform coordinates according to the specifications of the backend.
6.) Should a new artwork be added into the world, record it's transform and log it to the backend.
**/

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Networking;
using Newtonsoft.Json;
using Valve.VR.InteractionSystem;

namespace Syndetic {
    public class ArtworkManager : MonoBehaviour
    {
        public SyndeticApp app;
        public SyndeticArtworkThumbnail artworkThumbnailPrefab;
        public List<GameObject> selectableArtPlaceholders = new List<GameObject>();
        private int _thumbnailCount = 0;
        void Start(){
            for(int i = 0; i < selectableArtPlaceholders.Count; i++) {
                Destroy(selectableArtPlaceholders[i].GetComponent<MeshRenderer>());
                Destroy(selectableArtPlaceholders[i].GetComponent<MeshFilter>());
            }
            this._thumbnailCount = selectableArtPlaceholders.Count;
        }
        public void CallGetArtGallery(string uid="") {
            StartCoroutine(GetMyArtGallery(uid));
        }
        public void AddArtworkToWorld(string uid, bool currentlySelected) {
            StartCoroutine(CoroutineInstantiateArtwork(uid, currentlySelected, null));
        }
        public void LoadArtworkInWorld(string uid, bool currentlySelected, ArtworkTransform coordinates) {
            print("Loading Artwork Into world");
            StartCoroutine(CoroutineInstantiateArtwork(uid, currentlySelected, coordinates));
        }
        public string GenerateImageUrl(string uid, string filename) {
            return this.app.appServerSettings["servers"]["main"].ToString() +
                                                this.app.appServerSettings["cdn_endpoints"]["artwork_images_target"].ToString() + 
                                                "/" + uid + "/" + filename;
        }
        public IEnumerator CoroutineInstantiateArtwork(string uid, bool currentlySelected, ArtworkTransform coordinates=null) {

            /* TODO: Turn me into a coroutine, and eliminate image_url and fetch all artwork data here, instead of relying on
            getting data. */

            GameObject art = Instantiate(app.ArtworkPrefab.gameObject);
            Vector3 originalScale = art.transform.localScale;
            art.transform.localScale=Vector3.zero;
            art.GetComponent<Artwork>().app = this.app;
            art.GetComponent<Artwork>().uid = uid;
            art.GetComponent<Artwork>().currentlySelected = currentlySelected;
            if(currentlySelected) {
                art.GetComponentInChildren<ArtworkManipulateButton>().ManipulateArtwork();
            }

            /* Instantiate the artwork on the hand the laser triggered it. */
            GameObject player = null;
            if(this.app._fakeVR) {
                player = Player.instance.GetHand(0).noSteamVRFallbackCamera.gameObject;
            } else {
                player = Camera.main.gameObject;
            }
            
            if(player && coordinates == null) {

                coordinates = new ArtworkTransform();

                art.transform.SetParent(player.transform);
                art.transform.localPosition = coordinates.pos;
                art.transform.localRotation = coordinates.rot;
                art.transform.localScale = coordinates.scl;
            } else {
                art.transform.localPosition = coordinates.pos;
                art.transform.localRotation = coordinates.rot;
                art.transform.localScale = coordinates.scl;
            }

            art.transform.SetParent(null, true);

            UnityWebRequest request = UnityWebRequest.Get(this.app.appServerSettings["endpoints"]["artwork"]["display"].ToString()+"/"+uid);
            yield return request.SendWebRequest();
            if(request.isNetworkError) {
                Debug.Log("Error retrieving artwork.");
                yield break;
            }

            var response = JsonConvert.DeserializeObject<Dictionary<string, dynamic>>(request.downloadHandler.text);
            string artworkImageUrl = this.GenerateImageUrl(uid, (string)response["artwork"]["main_image"]);

            art.GetComponent<Artwork>().SetImage(artworkImageUrl);
            this.app.ToggleMenu();

            art.GetComponent<Artwork>().SaveOnLand();
        }

        // Current List of artwork
        public List<dynamic> currentArtworkList = new List<dynamic>();
        public int currentArtListPage = 0;

        public IEnumerator GetMyArtGallery(string uid) {
            /* Get a random artwork */

            // Display all of my artwork.
            print(this.app.appServerSettings["endpoints"]["artwork"]["display_all"].ToString()+"/artist/"+app.LoginObject.uid);
            UnityWebRequest request = UnityWebRequest.Get(this.app.appServerSettings["endpoints"]["artwork"]["display_all"].ToString()+"/artist/"+app.LoginObject.uid);
            yield return request.SendWebRequest();

            if (request.isNetworkError){
                Debug.Log("Error While Sending: " + request.error);
                yield break;
            }

            Debug.Log("Received: " + request.downloadHandler.text);
            var response = JsonConvert.DeserializeObject<Dictionary<string, dynamic>>(request.downloadHandler.text);
            Debug.Log(response);

            foreach(var art in response["artwork"]) {
                print(art);
                print(currentArtworkList);
                currentArtworkList.Add(art);
            }

            this.GenerateSelectableArtwork(currentArtListPage);
        }

        public void NextPage() {
            print("NextPage");
            print(this.currentArtworkList.Count);
            print((this.currentArtListPage+1)*selectableArtPlaceholders.Count);
            if(this.currentArtworkList.Count >= (this.currentArtListPage+1)*selectableArtPlaceholders.Count) {
                print("NextPageGO");
                this.currentArtListPage += 1;
                this.GenerateSelectableArtwork(currentArtListPage);
            }
        }

        public void PreviousPage() {
            print("PREVIOUSPAGE");
            if(0 <= (this.currentArtListPage-1)*selectableArtPlaceholders.Count) {
                this.currentArtListPage -= 1;
                this.GenerateSelectableArtwork(currentArtListPage);
            }
        }

        public void GoToPage(int page) {

        }

        public void GenerateSelectableArtwork(int page) {

            /* Remove Selectable Artwork*/
            //foreach(Transform child in this.app.syndeticMenu.UIArtGalleryListing.transform) {
            //    Destroy(child);
            //}

            /* Instantiate this._thumbnailCount Pieces of Artwork Paginated */
            int i_max = (int)Mathf.Min(currentArtworkList.Count, ((page+1)*this._thumbnailCount));
            int j = 0;

            for(int i = 0; i < this._thumbnailCount; i++) {
                if(selectableArtPlaceholders[i].transform.childCount > 0) {
                    Destroy(selectableArtPlaceholders[i].transform.GetChild(0).gameObject);
                }
            }

            for(int i = page*this._thumbnailCount; i < i_max; i++) {
                selectableArtPlaceholders[j].transform.localScale = Vector3.one;
                
                /* Instantiate Artwork Thumbnail with app and uid attached */
                GameObject artworkThumb = Instantiate(this.artworkThumbnailPrefab.gameObject);
                artworkThumb.transform.localScale = Vector3.zero;
                artworkThumb.GetComponent<SyndeticArtworkThumbnail>().app = this.app;
                artworkThumb.GetComponent<SyndeticArtworkThumbnail>().uid = (string)currentArtworkList[i]["uid"];

                artworkThumb.transform.parent = selectableArtPlaceholders[j].transform;

                /* Generate an IMAGE URL for the Thumbnail to retrieve the artwork. */
                Debug.Log(currentArtworkList[i]["main_image"]);
                string artworkImageUrl = this.GenerateImageUrl((string)currentArtworkList[i]["uid"], (string)currentArtworkList[i]["main_image"]);
                artworkThumb.GetComponent<SyndeticArtworkThumbnail>().SetImage(artworkImageUrl);
                artworkThumb.name = "ArtworkThumbnail_" + currentArtworkList[i]["uid"];
                artworkThumb.GetComponent<SyndeticArtworkThumbnail>().image_url = artworkImageUrl;

                artworkThumb.transform.localPosition = Vector3.zero;
                artworkThumb.transform.localRotation = Quaternion.Euler(Vector3.zero);

                j++;
            }
        }

    }
}