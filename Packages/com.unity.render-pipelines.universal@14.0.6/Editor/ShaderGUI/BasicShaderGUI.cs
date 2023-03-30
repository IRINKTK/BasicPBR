using System;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

public class BasicShaderGUI : ShaderGUI
{
    private enum SurfaceType
    {
        Opaque,
        Transparent
    }

    private enum BlendMode
    {
        Alpha,
        Additive
    }

    private enum RenderFace
    {
        Front = 2,
        Back = 1,
        Both = 0
    }



    #region PROPERTIES & GUITEXT
    // Surface type
    protected static GUIContent m_surfaceOptionsText = new GUIContent("Surface Options", "表面参数设置");
    protected MaterialProperty m_SurfaceTypeProp;
    protected static GUIContent m_SurfaceTypeText = new GUIContent("SurfaceType(渲染模式)", "实体/透明");

    // protected MaterialProperty m_ForceZWriteProp;
    // protected static GUIContent m_ForceZWriteText = new GUIContent("Force ZWrite(写入深度)");

    protected MaterialProperty m_DitherClippingProp;
    protected static GUIContent m_DitherClippingText = new GUIContent("Dither Clipping(抖动裁剪)");

    // Blend mode
    protected MaterialProperty m_BlendModeProp;
    protected static GUIContent m_BlendModeText = new GUIContent("BlendMode(混合模式)", "设置前景和背景的颜色混合方式");

    // Render face (Cull front/back/none)
    protected MaterialProperty m_CullModeProp;
    protected static GUIContent m_CullModeText = new GUIContent("Render Faces");
    protected MaterialProperty m_FlipNormalProp;
    protected static GUIContent m_FlipNormalText = new GUIContent("Flip Normal");

    // Alpha clip
    protected MaterialProperty m_AlphaClipProp;
    protected static GUIContent m_AlphaClipText = new GUIContent("AlphaClip(裁剪)", "开启/关闭裁剪");
    protected MaterialProperty m_AlphaClipThresholdProp;
    protected static GUIContent m_AlphaClipThresholdText = new GUIContent("Threshold(裁剪阈值)", "裁剪阈值");

    // Shadows
    protected MaterialProperty m_ReceiveShadowsProp;
    protected static GUIContent m_ReceiveShadowsText = new GUIContent("Receive Shadow(接受阴影)", "是否接受阴影");

    // Queue Offset
    protected MaterialProperty m_QueueOffsetProp;
    protected static GUIContent m_QueueOffsetText = new GUIContent("Queue Offset(渲染优先级)", "渲染队列的偏移量");
    protected const int m_QueueOffsetRange = 50;

    // Base map & color
    protected static GUIContent m_BaseMapInputs = new GUIContent("Base Input");
    protected MaterialProperty m_BaseMapProp;
    protected static GUIContent m_BaseMapText = new GUIContent("Base Map(主贴图)", "主贴图/固有色贴图");
    protected MaterialProperty m_BaseColorProp;
    protected static GUIContent m_BaseColorText = new GUIContent("Base Color(主颜色)", "主颜色/固有色");

    // Advance options
    protected bool m_AdvancedFoldout = false;
    protected static GUIContent m_AdvanceOptionsText = new GUIContent("Advance Options");

    // Custom Light Info
    protected MaterialProperty m_CustomLightProp;
    protected static GUIContent m_CustomLightText = new GUIContent("Enable Custom Light(自定义灯光)");
    protected MaterialProperty m_CustomLightDirProp;
    protected static GUIContent m_CustomLightDirText = new GUIContent("Custom Light Dir(自定义灯光方向)");
    protected MaterialProperty m_CustomLightColorProp;
    protected static GUIContent m_CustomLightColorText = new GUIContent("Custom Light Color(自定义灯光颜色)");


    #endregion

    private bool m_FirstApply = true;
    protected MaterialEditor m_MaterialEditor;


    public virtual void FindProperties(MaterialProperty[] properties)
    {
        // Surface options
        m_SurfaceTypeProp           = FindProperty("_Surface", properties);
        m_BlendModeProp             = FindProperty("_Blend", properties);
        m_CullModeProp              = FindProperty("_Cull", properties);
        m_FlipNormalProp            = FindProperty("_FlipNormal", properties);
        m_AlphaClipProp             = FindProperty("_AlphaClip", properties);
        m_AlphaClipThresholdProp    = FindProperty("_Cutoff", properties);
        m_ReceiveShadowsProp        = FindProperty("_ReceiveShadows", properties);
        m_QueueOffsetProp           = FindProperty("_QueueOffset", properties);
        m_DitherClippingProp        = FindProperty("_DitherClipping", properties);
        
        // Base inputs
        m_BaseMapProp               = FindProperty("_BaseMap", properties);
        m_BaseColorProp             = FindProperty("_BaseColor", properties);
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] materialProperties)
    {
        if (materialEditor == null)
        {
            throw new ArgumentNullException("Material Editor is null.");
        }

        FindProperties(materialProperties);
        m_MaterialEditor = materialEditor;
        Material material = m_MaterialEditor.target as Material;

        if (m_FirstApply)
        {
            foreach (Material mat in m_MaterialEditor.targets)
            {
                MaterialChanged(material);
            }
            m_FirstApply = false;
        }

        ShaderPropertiesGUI(material);
    }


    public virtual void ShaderPropertiesGUI(Material material)
    {
        if (material == null)
        {
            throw new ArgumentNullException("Material is null.");

        }
        EditorGUI.BeginChangeCheck();
        DrawSurfaceOptionsGUI(material);
        DrawBaseInputsGUI(material);
        if (EditorGUI.EndChangeCheck())
        {
            foreach (Material mat in m_MaterialEditor.targets)
            {
                MaterialChanged(mat);
            }
        }
    }

    public virtual void MaterialChanged(Material material)
    {
        if (material == null)
        {
            throw new ArgumentNullException("material");
        }

        material.shaderKeywords = null;
        SetupMaterialBlendMode(material);
        SetupMaterialKeywords(material);
    }

    private void DrawSurfaceOptionsGUI(Material material)
    {
        EditorGUILayout.LabelField(m_surfaceOptionsText, EditorStyles.boldLabel);

        // Surface type
        DoPopup(m_SurfaceTypeText, m_SurfaceTypeProp, Enum.GetNames(typeof(SurfaceType)));

        // Render face
        DoPopup(m_CullModeText, m_CullModeProp, Enum.GetNames(typeof(RenderFace)));
        if (m_CullModeProp.floatValue == (int)RenderFace.Both)
        {
            m_MaterialEditor.ShaderProperty(m_FlipNormalProp, m_FlipNormalText);
        }

        // Alpha clip
        EditorGUI.BeginChangeCheck();
        EditorGUI.showMixedValue = m_AlphaClipProp.hasMixedValue;
        var alphaClipEnabled = EditorGUILayout.Toggle(m_AlphaClipText, m_AlphaClipProp.floatValue == 1);
        if (EditorGUI.EndChangeCheck())
        {
            m_AlphaClipProp.floatValue = alphaClipEnabled ? 1 : 0;
        }
        if (m_AlphaClipProp.floatValue == 1)
        {
            m_MaterialEditor.ShaderProperty(m_AlphaClipThresholdProp, m_AlphaClipThresholdText, 1);
            m_MaterialEditor.ShaderProperty(m_DitherClippingProp, m_DitherClippingText, 1);
        }

        // Receive shadow
        if (m_ReceiveShadowsProp != null)
        {
            EditorGUI.BeginChangeCheck();
            var receiveShadows = EditorGUILayout.Toggle(m_ReceiveShadowsText, m_ReceiveShadowsProp.floatValue == 1.0f);
            if (EditorGUI.EndChangeCheck())
            {
                m_ReceiveShadowsProp.floatValue = receiveShadows ? 1 : 0;
            }
        }
    }

    public virtual void DrawAdvancedOptions(Material material)
    {
        EditorGUILayout.Space();
        m_AdvancedFoldout = EditorGUILayout.BeginFoldoutHeaderGroup(m_AdvancedFoldout, m_AdvanceOptionsText);

        if (m_AdvancedFoldout)
        {
            // Instancing
            m_MaterialEditor.EnableInstancingField();

            // Render priority
            if (m_QueueOffsetProp != null)
            {
                EditorGUI.BeginChangeCheck();
                EditorGUI.showMixedValue = m_QueueOffsetProp.hasMixedValue;
                var queue = EditorGUILayout.IntSlider(m_QueueOffsetText, (int)m_QueueOffsetProp.floatValue, -m_QueueOffsetRange, m_QueueOffsetRange);
                if (EditorGUI.EndChangeCheck())
                    m_QueueOffsetProp.floatValue = queue;
                EditorGUI.showMixedValue = false;
            }

        }

        EditorGUILayout.EndFoldoutHeaderGroup();
    }

    private void DrawBaseInputsGUI(Material material)
    {
        EditorGUILayout.Space();
        EditorGUILayout.BeginVertical("Box");
        {
            EditorGUILayout.LabelField(m_BaseMapInputs, EditorStyles.boldLabel);
            m_MaterialEditor.TexturePropertySingleLine(m_BaseMapText, m_BaseMapProp, m_BaseColorProp);
            m_MaterialEditor.TextureScaleOffsetProperty(m_BaseMapProp);
        }
        EditorGUILayout.EndVertical();
    }

    private void SetupMaterialBlendMode(Material material)
    {
        if (material == null)
        {
            throw new ArgumentNullException("material");
        }

        bool alphaClip = false;
        if (material.HasProperty("_AlphaClip"))
            alphaClip = material.GetFloat("_AlphaClip") >= 0.5;

        if (material.HasProperty("_Surface"))
        {
            SurfaceType surfaceType = (SurfaceType)material.GetFloat("_Surface");
            if (surfaceType == SurfaceType.Opaque)
            {
                if (alphaClip)
                {
                    material.renderQueue = (int)RenderQueue.AlphaTest;
                    material.SetOverrideTag("RenderType", "TransparentCutout");
                }
                else
                {
                    material.renderQueue = (int)RenderQueue.Geometry;
                    material.SetOverrideTag("RenderType", "Opaque");
                }

                material.renderQueue += material.HasProperty("_QueueOffset") ? (int)material.GetFloat("_QueueOffset") : 0;
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetInt("_ZWrite", 1);
                material.SetShaderPassEnabled("ShadowCaster", true);
                material.SetShaderPassEnabled("DepthOnly", true);
            }
            else
            {
                // General Transparent Material Settings
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                material.SetOverrideTag("RenderType", "Transparent");
                material.SetInt("_ZWrite", 0);
                material.renderQueue = (int)RenderQueue.Transparent;
                material.renderQueue += material.HasProperty("_QueueOffset") ? (int)material.GetFloat("_QueueOffset") : 0;
                material.SetShaderPassEnabled("ShadowCaster", false);
                material.SetShaderPassEnabled("DepthOnly", false);
                // if (m_ForceZWriteProp.floatValue == 1.0) 
                // {
                //     material.SetInt("_ZWrite", 1);
                //     material.SetShaderPassEnabled("ShadowCaster", true);
                // }
            }
        }
    }

    public virtual void SetupMaterialKeywords(Material material)
    {
        material.shaderKeywords = null;
        material.SetKeyword("_ALPHATEST_ON", m_AlphaClipProp.floatValue != 0.0f);
        material.SetKeyword("_RECEIVE_SHADOWS_OFF", m_ReceiveShadowsProp.floatValue == 0.0f);
        material.SetKeyword("_DITHER_CLIPPING", m_DitherClippingProp.floatValue != 0.0f);
        material.SetKeyword("_FLIP_NORMAL", m_FlipNormalProp.floatValue == 1.0f);
    }

    public void DoPopup(GUIContent label, MaterialProperty property, string[] options)
    {
        DoPopup(label, property, options, m_MaterialEditor);
    }

    public static void DoPopup(GUIContent label, MaterialProperty property, string[] options, MaterialEditor materialEditor)
    {
        if (property == null)
            throw new ArgumentNullException("property");

        EditorGUI.showMixedValue = property.hasMixedValue;

        var mode = property.floatValue;
        EditorGUI.BeginChangeCheck();
        mode = EditorGUILayout.Popup(label, (int)mode, options);
        if (EditorGUI.EndChangeCheck())
        {
            materialEditor.RegisterPropertyChangeUndo(label.text);
            property.floatValue = mode;
        }

        EditorGUI.showMixedValue = false;
    }
}

