using System;
using UnityEngine;
using UnityEditor;

public class DefaultLitShaderGUI : BasicShaderGUI
{
    enum RimDirection
    {
        All,
        Front,
        Back,
    }


    static GUIContent m_PBRInputsText = new GUIContent("PBR Basic");

    // Bump
    MaterialProperty m_BumpMapProp;
    static GUIContent m_BumpMapText = new GUIContent("Normal Map(法线贴图)");
    MaterialProperty m_BumpScaleProp;
    static GUIContent m_BumpScaleText = new GUIContent("Normal Scale(法线强度)");

    // Roughness, Metallic, Occlusion
    MaterialProperty m_MixMapProp;
    static GUIContent m_MixMapText = new GUIContent("MixMap(R, M, O)");
    MaterialProperty m_RoughnessProp;
    static GUIContent m_RoughnessText = new GUIContent("Roughness(粗糙度)");
    MaterialProperty m_MetallicProp;
    static GUIContent m_MetallicText = new GUIContent("Metallic(金属度)");
    MaterialProperty m_OcclusionProp;
    static GUIContent m_OcclusionText = new GUIContent("Occlusion(AO)");
    MaterialProperty m_ReflectanceProp;
    static GUIContent m_ReflectanceText = new GUIContent("Reflectance(反射率)");


    // Extra properties
    static GUIContent m_ExtraInuptsText = new GUIContent("PBR Extra");

    // Emissive
    MaterialProperty m_EmissionProp;
    static GUIContent m_EmissionText = new GUIContent("Emission(自发光)");
    MaterialProperty m_EmissionMapProp;
    static GUIContent m_EmissionMapText = new GUIContent("Emission(自发光贴图)");
    MaterialProperty m_EmissionColorProp;
    static GUIContent m_EmissionColorText = new GUIContent("Emission Color(自发光颜色)");

    // Laser
    MaterialProperty m_LaserProp;
    static GUIContent m_LaserText = new GUIContent("Laser(镭射)");
    MaterialProperty m_LaserMapProp;
    static GUIContent m_LaserMapText = new GUIContent("Laser Map");
    MaterialProperty m_LaserValueProp;
    static GUIContent m_LaserValueText = new GUIContent("Laser Value");


    // Rim light
    MaterialProperty m_RimLightProp;
    static GUIContent m_RimLightText = new GUIContent("Rim Light(边缘光)");
    MaterialProperty m_RimDirectionProp;
    static GUIContent m_RimDirectionText = new GUIContent("Rim Direction(边缘光方向)");
    MaterialProperty m_RimColorProp;
    static GUIContent m_RimColorText = new GUIContent("Rim Color(边缘光颜色)");
    MaterialProperty m_RimParamsProp;
    static GUIContent m_RimMinMaxText = new GUIContent("Rim Min Max(边缘光范围)");


    public override void FindProperties(MaterialProperty[] properties)
    {
        base.FindProperties(properties);

        m_BumpMapProp               = FindProperty("_BumpMap", properties);
        m_BumpScaleProp             = FindProperty("_BumpScale", properties);

        m_MixMapProp                = FindProperty("_MixMap", properties);
        m_RoughnessProp             = FindProperty("_Roughness", properties);
        m_MetallicProp              = FindProperty("_Metallic", properties);
        m_OcclusionProp             = FindProperty("_Occlusion", properties);
        m_ReflectanceProp           = FindProperty("_Reflectance", properties);

        m_EmissionProp              = FindProperty("_Emission", properties);
        m_EmissionMapProp           = FindProperty("_EmissionMap", properties);
        m_EmissionColorProp         = FindProperty("_EmissionColor", properties);

        m_LaserProp                 = FindProperty("_Laser", properties);
        m_LaserMapProp              = FindProperty("_LaserMap", properties);
        m_LaserValueProp            = FindProperty("_LaserValue", properties);

        m_RimLightProp              = FindProperty("_Rim", properties);
        m_RimDirectionProp          = FindProperty("_RimDirection", properties);
        m_RimColorProp              = FindProperty("_RimColor", properties);
        m_RimParamsProp             = FindProperty("_RimParams", properties);
    }

    public override void ShaderPropertiesGUI(Material material)
    {
        if (material == null)
        {
            throw new ArgumentNullException("Material is null.");
        }

        EditorGUI.BeginChangeCheck();
        base.ShaderPropertiesGUI(material);
        DrawPBRInputGUI(material);
        base.DrawAdvancedOptions(material);
        if (EditorGUI.EndChangeCheck())
        {
            foreach (Material mat in m_MaterialEditor.targets)
            {
                MaterialChanged(mat);
            }
        }
    }

    public override void SetupMaterialKeywords(Material material)
    {
        base.SetupMaterialKeywords(material);
        material.SetKeyword("_NORMALMAP", m_BumpMapProp.textureValue != null);
        material.SetKeyword("_MIXMAP", m_MixMapProp.textureValue != null);
        material.SetKeyword("_EMISSION", m_EmissionProp.floatValue != 0.0f);
        material.SetKeyword("_LASER", m_LaserProp.floatValue != 0.0f && m_LaserMapProp.textureValue != null);

        RimDirection rimDirection = (RimDirection)m_RimDirectionProp.floatValue;
        switch (rimDirection)
        {
            case RimDirection.All:
                break;
            case RimDirection.Front:
                material.EnableKeyword("_RIM_FRONT");
                break;
            case RimDirection.Back:
                material.EnableKeyword("_RIM_BACK");
                break;
            default:
                break;
        }
        material.SetKeyword("_RIM_LIGHT", m_RimLightProp.floatValue != 0.0f);
    }

    void DrawPBRInputGUI(Material material)
    {
        
        EditorGUILayout.Space();
        EditorGUILayout.BeginVertical("Box");
        {
            EditorGUILayout.LabelField(m_PBRInputsText, EditorStyles.boldLabel);

            // Bump
            m_MaterialEditor.TexturePropertySingleLine(m_BumpMapText, m_BumpMapProp, m_BumpScaleProp);

            // MixMap
            m_MaterialEditor.TexturePropertySingleLine(m_MixMapText, m_MixMapProp);
            m_MaterialEditor.ShaderProperty(m_RoughnessProp, m_RoughnessText);
            m_MaterialEditor.ShaderProperty(m_MetallicProp, m_MetallicText);
            m_MaterialEditor.ShaderProperty(m_OcclusionProp, m_OcclusionText);
            m_MaterialEditor.ShaderProperty(m_ReflectanceProp, m_ReflectanceText);
        }
        EditorGUILayout.EndVertical();


        EditorGUILayout.Space();
        EditorGUILayout.BeginVertical("Box");
        {
            EditorGUILayout.LabelField(m_ExtraInuptsText, EditorStyles.boldLabel);

            // Emission
            EditorGUILayout.BeginVertical("Button");
            bool bEmission = m_EmissionProp.floatValue != 0.0f ? true : false;
            m_EmissionProp.floatValue = EditorGUILayout.ToggleLeft(m_EmissionText.text, bEmission) ? 1.0f : 0.0f;
            if (bEmission)
            {
                m_MaterialEditor.TexturePropertySingleLine(m_EmissionMapText, m_EmissionMapProp, m_EmissionColorProp);
                BakeEmission(m_MaterialEditor);
            }
            EditorGUILayout.EndVertical();
            
            // Laser
            EditorGUILayout.BeginVertical("Button");
            bool bLaser = m_LaserProp.floatValue != 0.0f ? true : false;
            m_LaserProp.floatValue = EditorGUILayout.ToggleLeft(m_LaserText.text, bLaser) ? 1.0f : 0.0f;
            if (bLaser)
            {
                m_MaterialEditor.TexturePropertySingleLine(m_LaserMapText, m_LaserMapProp, m_LaserValueProp);
            }
            EditorGUILayout.EndVertical();

            // Rim Light
            EditorGUILayout.BeginVertical("Button");
            bool bRimLight = m_RimLightProp.floatValue != 0.0f ? true : false;
            m_RimLightProp.floatValue = EditorGUILayout.ToggleLeft(m_RimLightText.text, bRimLight) ? 1.0f : 0.0f;
            if (bRimLight)
            {
                DoPopup(m_RimDirectionText, m_RimDirectionProp, Enum.GetNames(typeof(RimDirection)));
                m_MaterialEditor.ShaderProperty(m_RimColorProp, m_RimColorText);
                Vector2 rimParams = material.GetVector("_RimParams");
                EditorGUILayout.MinMaxSlider(m_RimMinMaxText, ref rimParams.x, ref rimParams.y, 0, 1);
                m_RimParamsProp.vectorValue = rimParams;
            }
            EditorGUILayout.EndVertical();
        }
        EditorGUILayout.EndVertical();
    }


    void BakeEmission(MaterialEditor materialEditor)
    {
        EditorGUI.BeginChangeCheck();
        materialEditor.LightmapEmissionProperty(2);
        if (EditorGUI.EndChangeCheck())
        {
            foreach (Material material in materialEditor.targets)
            {
                material.globalIlluminationFlags &= MaterialGlobalIlluminationFlags.BakedEmissive;
            }
        }
    }

}
