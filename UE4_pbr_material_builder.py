"""
Unreal Engine Character builder
Christopher Phyffer 2020
https://phyffer.com

Please note, this is only a PARTIAL script with some critical elements missing, I cannot release the entire thing.

This script automates the character import pipeline by performing the following:
1.) Create a Set of directories from the given Character's name, see the Character.__init__() constructor 
2.) Import the skeletal mesh FBX and configure it's import options. `SKELETAL_MESH_NAME`
3.) Import the textures for the character as specified by `FROM_TEXTURES_DIRECTORY`
    3a.) Note: The textures as well as it's channels must adhere to the right suffix set. See method: `Character.build_materials()`
5.) Develop the material instance for the Character and assign textures to the material according to it's proper suffix (ArmsMap, NormalMap)
6.) Assign the materials to the appropriate skeletal mesh's slot name.
"""

import re
import unreal
import os

# Build character directories

# Import Character FBX from directory

# Import Character Textures from directory

# Analyze Character FBX and build new materials from it

class Character:

    ASSET_NAME = r''#'Azula'
    SKELETAL_MESH_NAME = r''#'azula_MA_RU_AI_RM_Rig'
    FROM_TEXTURES_DIRECTORY = r''#r"D:\Art_People\ATLA Azula\Dist\Textures"
    FBX_IMPORT_PATH = r''#r"D:\Art_People\ATLA Azula\Dist\azula_MA_RU_AI_RM_Rig.fbx"

    CHARACTER_DIRECTORY = r''
    MATERIALS_DIRECTORY = r''
    MESHES_DESTINATION_DIRECTORY = r''
    DESTINATION_TEXTURES_DIRECTORY = r''

    def __init__(self, asset_name, skel_mesh_name, fbx_path, textures_directory, debug=False):
        unreal.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
        unreal.log('~ PHYFFER CHARACTER BUILDER    ~')
        unreal.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')

        self.ASSET_NAME = asset_name
        self.SKELETAL_MESH_NAME = skel_mesh_name
        self.FROM_TEXTURES_DIRECTORY = textures_directory
        self.FBX_IMPORT_PATH = fbx_path

        self.CHARACTER_DIRECTORY = '/Game/_Characters/{asset_name}'.format(asset_name=self.ASSET_NAME)
        self.MATERIALS_DIRECTORY = '/Game/_Characters/{asset_name}/Materials'.format(asset_name=self.ASSET_NAME)
        self.MESHES_DESTINATION_DIRECTORY = '/Game/_Characters/{asset_name}/Meshes'.format(asset_name=self.ASSET_NAME)
        self.DESTINATION_TEXTURES_DIRECTORY = '/Game/_Characters/{asset_name}/Textures'.format(asset_name=self.ASSET_NAME)

        print(r'ASSET_NAME : ' + self.ASSET_NAME)
        print(r'SKELETAL_MESH_NAME : ' + self.SKELETAL_MESH_NAME)
        print(r'FROM_TEXTURES_DIRECTORY : ' + self.FROM_TEXTURES_DIRECTORY)
        print(r'FBX_IMPORT_PATH : ' + self.FBX_IMPORT_PATH)
        print(r'CHARACTER_DIRECTORY' + self.CHARACTER_DIRECTORY)
        print(r'MATERIALS_DIRECTORY' + self.MATERIALS_DIRECTORY)
        print(r'MESHES_DESTINATION_DIRECTORY' + self.MESHES_DESTINATION_DIRECTORY)
        print(r'DESTINATION_TEXTURES_DIRECTORY' + self.DESTINATION_TEXTURES_DIRECTORY)

        if debug:
            return

        self.build_character()

    def build_character(self):
        error = False
        if not self.ASSET_NAME or not self.SKELETAL_MESH_NAME or not self.FROM_TEXTURES_DIRECTORY or not self.FBX_IMPORT_PATH:
            error = True
            unreal.log_error('self.ASSET_NAME, self.SKELETAL_MESH_NAME, self.FROM_TEXTURES_DIRECTORY, self.FBX_IMPORT_PATH is required')


        unreal.EditorAssetLibrary.make_directory(self.CHARACTER_DIRECTORY)
        unreal.EditorAssetLibrary.make_directory(self.MATERIALS_DIRECTORY)
        unreal.EditorAssetLibrary.make_directory(self.MESHES_DESTINATION_DIRECTORY)
        unreal.EditorAssetLibrary.make_directory(self.DESTINATION_TEXTURES_DIRECTORY)

        self.import_skeletal_mesh()
        textures_dict = self.import_textures()
        materials_dict = self.build_materials(textures_dict)
        self.assign_materials_to_mesh(materials_dict)

        unreal.log('+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++')
        unreal.log('+ PHYFFER CHARACTER BUILDER COMPLETED !!!!   +')
        unreal.log('+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++')

    def assign_materials_to_mesh(self, materials_dict):
        unreal.log("=========================================")
        unreal.log(materials_dict)
        unreal.log("=========================================")

        #Attach Materials to Skeletal Mesh Later
        sk_mesh_path = self.MESHES_DESTINATION_DIRECTORY + '/' + self.SKELETAL_MESH_NAME
        sk_mesh = unreal.load_asset(sk_mesh_path)
        if not sk_mesh:
            unreal.log_error("SKELETAL MESH NOT FOUND TO ASSIGN MATERIALS TO: {}".format(sk_mesh_path))
            return

        commit_materials = []
        for i, m in enumerate(sk_mesh.materials):
            slot_name = str(m.material_slot_name)

            if slot_name in materials_dict:
                unreal.log("SLOT NAME CONFIRMED: {}".format(slot_name) )
                sk_material = unreal.SkeletalMaterial(material_interface=materials_dict[slot_name], material_slot_name=slot_name)
            else:
                unreal.log_error("SLOT NAME HAS NO MATERIAL MATCH: {}".format(slot_name) )
                sk_material = unreal.SkeletalMaterial(material_interface=m.material_interface, material_slot_name=slot_name)
            
            unreal.log(sk_material)
            commit_materials.append(sk_material)

        sk_mesh.set_editor_property('materials', commit_materials)

        self.save_assets([sk_mesh, sk_mesh.skeleton, sk_mesh.physics_asset])

    def import_textures(self):
        """
        Import Textures and set the appropriate Compression, sRGB and LOD Settings
        """

        # Textures List Grab
        files = os.listdir(self.FROM_TEXTURES_DIRECTORY)

        import_tasks = []
        for texture_file in files:
            unreal.log(texture_file)

            # Create an import task.
            import_task = unreal.AssetImportTask()

            # Set base properties on the import task.
            import_task.filename = os.path.join(self.FROM_TEXTURES_DIRECTORY, texture_file)
            import_task.destination_path = self.DESTINATION_TEXTURES_DIRECTORY
            import_task.destination_name = texture_file.split('.')[0]
            import_task.automated = True  # Suppress UI.

            import_tasks.append(import_task)

        # Import the skeletalMesh.
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(
            import_tasks  # Expects a list for multiple import tasks.
        )

        imported_assets = import_task.get_editor_property("imported_object_paths")

        saved_assets = []
        built_textures = {}
        for import_task in import_tasks:
            unreal.log( import_task.get_editor_property("imported_object_paths") )
            loaded_texture = unreal.load_asset(self.DESTINATION_TEXTURES_DIRECTORY+'/'+import_task.destination_name)
            saved_assets.append(loaded_texture)

            target_material_slot_name = re.sub(r'(^TX_)|(_(ARMS|ARM|TSCH|TCSH|BaseColor_Opacity|DO|Diffuse|BaseColor|NM|N|Normal)$)', r'', import_task.destination_name)
            if target_material_slot_name not in built_textures:
                built_textures[target_material_slot_name] = {}

            if re.search(".*(_ARMS|_ARM)$", import_task.destination_name):
                loaded_texture.srgb = False
                loaded_texture.compression_settings = unreal.TextureCompressionSettings.TC_DEFAULT
                loaded_texture.lod_group = unreal.TextureGroup.TEXTUREGROUP_CHARACTER
                built_textures[target_material_slot_name]['ArmsMap'] = loaded_texture
                continue
            
            elif re.search(".*(_TSCH|_TCSH)$", import_task.destination_name):
                loaded_texture.srgb = False
                loaded_texture.compression_settings = unreal.TextureCompressionSettings.TC_DEFAULT
                loaded_texture.lod_group = unreal.TextureGroup.TEXTUREGROUP_CHARACTER
                built_textures[target_material_slot_name]['TcshMap'] = loaded_texture
                continue

            elif re.search(".*(_BaseColor_Opacity|_DO|_Diffuse|_BaseColor)$", import_task.destination_name):
                loaded_texture.compression_settings = unreal.TextureCompressionSettings.TC_DEFAULT
                loaded_texture.lod_group = unreal.TextureGroup.TEXTUREGROUP_CHARACTER
                built_textures[target_material_slot_name]['DiffuseMap'] = loaded_texture
                continue


    def import_skeletal_mesh(self):

        # Create an import task.
        import_task = unreal.AssetImportTask()

        # Set base properties on the import task.
        import_task.filename = self.FBX_IMPORT_PATH
        import_task.destination_path = self.MESHES_DESTINATION_DIRECTORY
        import_task.destination_name = self.SKELETAL_MESH_NAME
        import_task.automated = True  # Suppress UI.

        # Set the skeletal mesh options on the import task.
        import_task.options = self._get_skeletal_mesh_import_options()

        # Import the skeletalMesh.
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(
            [import_task]  # Expects a list for multiple import tasks.
        )
        imported_assets = import_task.get_editor_property(
            "imported_object_paths"
        )

        if not imported_assets:
            unreal.log_warning("No assets were imported!")
            return

        # Return the instance of the imported SkeletalMesh
        return unreal.load_asset(imported_assets[0])



    def save_assets(self, assets, force_save=False):
        """
        Saves the given asset objects.
        :param list assets: List of asset objects to save.
        :param bool force_save: Will save regardless if the asset is dirty or not.
        :return: True if all assets were saved correctly, false if not; the failed
        assets are returned if necessary.
        :rtype: bool, list[unreal.Object]
        """
        failed_assets = []
        only_if_is_dirty = not force_save
        assets = assets if isinstance(assets, list) else [assets]

        for asset in assets:
            asset_path = asset.get_full_name()
            if unreal.EditorAssetLibrary.save_asset(asset_path, only_if_is_dirty):
                unreal.log(
                    "Saved newly created asset: {}".format(asset_path)
                )
            else:
                unreal.log_warning(
                    "FAILED TO SAVE newly created asset: {}".format(asset_path)
                )
                failed_assets.append(asset)

        return len(failed_assets) == 0, failed_assets