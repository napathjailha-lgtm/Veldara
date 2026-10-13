using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

/// <summary>Procedural PC prototype for Veldara's monster capture, training, and evolution loop.</summary>
public sealed class VeldaraPrototype : MonoBehaviour
{
    private sealed class MonsterData
    {
        public string species, nextForm;
        public int level = 1, xp, bond, power = 10;
        public Color color;
        public MonsterData(string species, string nextForm, Color color)
        { this.species = species; this.nextForm = nextForm; this.color = color; }
    }

    private sealed class WildMonster : MonoBehaviour
    {
        public string species, nextForm;
        public int level;
        public Color color;
        public float seed;
        public Vector3 home;
        private void Update()
        {
            float t = Time.time * 0.55f + seed;
            Vector3 target = home + new Vector3(Mathf.Sin(t) * 0.75f, 0f, Mathf.Cos(t * 0.7f) * 0.75f);
            transform.position = Vector3.Lerp(transform.position, target, Time.deltaTime * 0.8f);
            transform.Rotate(0f, 20f * Time.deltaTime, 0f, Space.World);
        }
    }

    private readonly List<MonsterData> roster = new List<MonsterData>();
    private readonly List<WildMonster> wild = new List<WildMonster>();
    private Transform player, partner;
    private Camera gameCamera;
    private readonly Vector3 cameraOffset = new Vector3(0f, 8f, -9f);
    private int activeIndex, coins = 30;
    private string status = "Welcome to Veldara! Find a wild monster and press E to capture.";
    private float statusUntil;
    private GUIStyle titleStyle, panelStyle, textStyle, buttonStyle, smallStyle;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void Boot()
    {
        if (FindFirstObjectByType<VeldaraPrototype>() != null) return;
        new GameObject("Veldara Prototype Runtime").AddComponent<VeldaraPrototype>();
    }

    private void Start()
    {
        Application.targetFrameRate = 120;
        BuildArena();
        BuildPlayer();
        BuildWildMonsters();
        BuildCamera();
        roster.Add(new MonsterData("Mossling", "Thornback", new Color(0.25f, 0.8f, 0.38f)) { power = 12 });
        SpawnPartner();
        SetStatus("Starter received: Mossling. WASD to move; approach a wild monster and press E.");
    }

    private void Update()
    {
        if (player == null) return;
        Keyboard k = Keyboard.current;
        if (k != null)
        {
            Vector2 move = Vector2.zero;
            if (k.wKey.isPressed || k.upArrowKey.isPressed) move.y++;
            if (k.sKey.isPressed || k.downArrowKey.isPressed) move.y--;
            if (k.dKey.isPressed || k.rightArrowKey.isPressed) move.x++;
            if (k.aKey.isPressed || k.leftArrowKey.isPressed) move.x--;
            if (move.sqrMagnitude > 1f) move.Normalize();
            player.position += new Vector3(move.x, 0f, move.y) * 5.5f * Time.deltaTime;
            if (k.eKey.wasPressedThisFrame) TryCapture();
            if (k.tKey.wasPressedThisFrame) TrainActive();
            if (k.uKey.wasPressedThisFrame) EvolveActive();
            if (k.tabKey.wasPressedThisFrame) CyclePartner();
        }
        player.position = new Vector3(Mathf.Clamp(player.position.x, -18f, 18f), 0f, Mathf.Clamp(player.position.z, -18f, 18f));
        if (partner != null)
        {
            partner.position = Vector3.Lerp(partner.position, player.position + new Vector3(-1.1f, 0f, -0.8f), Time.deltaTime * 5f);
            partner.LookAt(new Vector3(player.position.x, partner.position.y, player.position.z));
        }
        if (gameCamera != null)
        {
            gameCamera.transform.position = player.position + cameraOffset;
            gameCamera.transform.LookAt(player.position + Vector3.up * 0.5f);
        }
    }

    private void BuildArena()
    {
        RenderSettings.ambientLight = new Color(0.52f, 0.56f, 0.62f);
        GameObject ground = GameObject.CreatePrimitive(PrimitiveType.Cube);
        ground.name = "Procedural Meadow";
        ground.transform.position = new Vector3(0f, -0.35f, 0f);
        ground.transform.localScale = new Vector3(40f, 0.5f, 40f);
        SetColor(ground, new Color(0.19f, 0.36f, 0.24f));
        for (int i = 0; i < 30; i++)
        {
            float a = i * Mathf.PI * 2f / 30f;
            GameObject rock = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            rock.name = "Meadow Boundary Rock";
            rock.transform.position = new Vector3(Mathf.Cos(a) * 19f, 0.3f, Mathf.Sin(a) * 19f);
            rock.transform.localScale = new Vector3(0.9f, 0.7f, 0.9f);
            SetColor(rock, new Color(0.28f, 0.31f, 0.3f));
        }
        for (int i = 0; i < 14; i++)
        {
            float x = Mathf.Sin(i * 12.3f) * 16f, z = Mathf.Cos(i * 8.1f) * 16f;
            GameObject trunk = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            trunk.name = "Low-poly Tree Trunk";
            trunk.transform.position = new Vector3(x, 0.65f, z);
            trunk.transform.localScale = new Vector3(0.28f, 0.65f, 0.28f);
            SetColor(trunk, new Color(0.28f, 0.18f, 0.11f));
            GameObject crown = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            crown.name = "Low-poly Tree Crown";
            crown.transform.position = new Vector3(x, 1.65f, z);
            crown.transform.localScale = new Vector3(1.25f, 1.45f, 1.25f);
            SetColor(crown, new Color(0.12f, 0.43f, 0.22f));
        }
        if (FindFirstObjectByType<Light>() == null)
        {
            GameObject sunObject = new GameObject("Veldara Sun");
            Light sun = sunObject.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.intensity = 1.25f;
            sunObject.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
        }
    }

    private void BuildPlayer()
    {
        GameObject body = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        body.name = "Tamer";
        body.transform.position = Vector3.zero;
        body.transform.localScale = new Vector3(0.75f, 1f, 0.75f);
        SetColor(body, new Color(0.25f, 0.58f, 0.95f));
        player = body.transform;
    }

    private void BuildWildMonsters()
    {
        CreateWild("Embercub", "Flarefang", 2, new Color(0.95f, 0.34f, 0.16f), new Vector3(5f, 0.65f, 2f));
        CreateWild("Pebblit", "Cragolem", 1, new Color(0.66f, 0.61f, 0.48f), new Vector3(-5f, 0.65f, 3f));
        CreateWild("Mossling", "Thornback", 2, new Color(0.25f, 0.8f, 0.38f), new Vector3(2f, 0.65f, 7f));
        CreateWild("Embercub", "Flarefang", 3, new Color(0.95f, 0.34f, 0.16f), new Vector3(-8f, 0.65f, -4f));
        CreateWild("Pebblit", "Cragolem", 3, new Color(0.66f, 0.61f, 0.48f), new Vector3(8f, 0.65f, -7f));
    }

    private void CreateWild(string species, string nextForm, int level, Color color, Vector3 position)
    {
        GameObject obj = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        obj.name = "Wild " + species;
        obj.transform.position = position;
        obj.transform.localScale = Vector3.one * 1.05f;
        SetColor(obj, color);
        WildMonster monster = obj.AddComponent<WildMonster>();
        monster.species = species; monster.nextForm = nextForm; monster.level = level;
        monster.color = color; monster.seed = Random.Range(0f, 20f); monster.home = position;
        wild.Add(monster);
        GameObject eye = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        eye.name = "Monster Eye"; eye.transform.SetParent(obj.transform, false);
        eye.transform.localPosition = new Vector3(0.25f, 0.18f, 0.39f);
        eye.transform.localScale = new Vector3(0.17f, 0.17f, 0.12f);
        SetColor(eye, Color.white);
        Collider eyeCollider = eye.GetComponent<Collider>();
        if (eyeCollider != null) Destroy(eyeCollider);
    }

    private void BuildCamera()
    {
        gameCamera = Camera.main;
        if (gameCamera == null)
        {
            GameObject cam = new GameObject("Main Camera");
            gameCamera = cam.AddComponent<Camera>();
            cam.AddComponent<AudioListener>();
            cam.tag = "MainCamera";
        }
        gameCamera.transform.position = player.position + cameraOffset;
        gameCamera.transform.LookAt(player.position);
        gameCamera.fieldOfView = 55f;
        gameCamera.backgroundColor = new Color(0.53f, 0.72f, 0.88f);
    }

    private void SpawnPartner()
    {
        if (partner != null) Destroy(partner.gameObject);
        if (roster.Count == 0) return;
        MonsterData data = roster[Mathf.Clamp(activeIndex, 0, roster.Count - 1)];
        GameObject obj = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        obj.name = "Partner - " + data.species;
        obj.transform.position = player.position + new Vector3(-1f, 0f, -1f);
        obj.transform.localScale = Vector3.one * 0.72f;
        SetColor(obj, data.color);
        Collider col = obj.GetComponent<Collider>();
        if (col != null) Destroy(col);
        partner = obj.transform;
    }

    private void TryCapture()
    {
        WildMonster target = FindNearestWild(3.2f);
        if (target == null) { SetStatus("No wild monster close enough. Approach within range and press E."); return; }
        float chance = Mathf.Clamp(0.78f - (target.level - 1) * 0.1f, 0.35f, 0.78f);
        if (Random.value <= chance)
        {
            MonsterData caught = new MonsterData(target.species, target.nextForm, target.color);
            caught.level = target.level; caught.power = 10 + target.level * 2;
            roster.Add(caught); wild.Remove(target); Destroy(target.gameObject); coins += 5;
            SetStatus("Captured " + caught.species + " Lv." + caught.level + "! Collection +1, reward +5 coins.");
        }
        else { coins = Mathf.Max(0, coins - 2); SetStatus("Capture failed; monster escaped. (-2 coins)"); }
    }

    private WildMonster FindNearestWild(float maxDistance)
    {
        WildMonster nearest = null; float best = maxDistance;
        for (int i = wild.Count - 1; i >= 0; i--)
        {
            if (wild[i] == null) { wild.RemoveAt(i); continue; }
            float distance = Vector3.Distance(player.position, wild[i].transform.position);
            if (distance < best) { best = distance; nearest = wild[i]; }
        }
        return nearest;
    }

    private void TrainActive()
    {
        if (roster.Count == 0) { SetStatus("Capture a monster first."); return; }
        MonsterData data = roster[activeIndex]; data.xp++; data.bond++;
        if (data.xp >= 3) { data.xp = 0; data.level++; data.power += 3; SetStatus(data.species + " reached Lv." + data.level + "! Power increased."); }
        else SetStatus(data.species + " trained. Progress " + data.xp + "/3, bond " + data.bond + ".");
    }

    private void EvolveActive()
    {
        if (roster.Count == 0) return;
        MonsterData data = roster[activeIndex];
        if (string.IsNullOrEmpty(data.nextForm)) { SetStatus(data.species + " has reached its current final form."); return; }
        if (data.level < 5) { SetStatus("Evolution locked. Train to Lv.5 first (current Lv." + data.level + ")."); return; }
        string old = data.species; data.species = data.nextForm;
        data.nextForm = data.species == "Thornback" ? "Verdantaur" :
                        data.species == "Flarefang" ? "Solwyrm" :
                        data.species == "Cragolem" ? "Mountainox" : "";
        data.power += 12; data.color = Color.Lerp(data.color, Color.white, 0.25f);
        SpawnPartner(); SetStatus("EVOLUTION! " + old + " evolved into " + data.species + ". Power +12.");
    }

    private void CyclePartner()
    {
        if (roster.Count < 2) { SetStatus("Capture more monsters to switch partners."); return; }
        activeIndex = (activeIndex + 1) % roster.Count; SpawnPartner();
        SetStatus("Active partner: " + roster[activeIndex].species + ".");
    }

    private void SetStatus(string message)
    {
        status = message; statusUntil = Time.time + 6f; Debug.Log("[Veldara] " + message);
    }

    private static void SetColor(GameObject obj, Color color)
    {
        Renderer r = obj.GetComponent<Renderer>();
        if (r != null) r.material.color = color;
    }

    private void OnGUI()
    {
        EnsureStyles();
        GUI.Box(new Rect(16, 16, 330, 138), GUIContent.none, panelStyle);
        GUI.Label(new Rect(30, 22, 300, 30), "VELDARA | WILD FRONTIER", titleStyle);
        GUI.Label(new Rect(30, 55, 300, 24), "Coins: " + coins + "    Collection: " + roster.Count, textStyle);
        GUI.Label(new Rect(30, 80, 300, 22), "WASD move | E capture | T train", smallStyle);
        GUI.Label(new Rect(30, 101, 300, 22), "U evolve (Lv.5) | TAB switch partner", smallStyle);
        GUI.Box(new Rect(16, 164, 330, 182), GUIContent.none, panelStyle);
        GUI.Label(new Rect(30, 171, 300, 28), "ACTIVE PARTNER", titleStyle);
        if (roster.Count > 0)
        {
            MonsterData d = roster[Mathf.Clamp(activeIndex, 0, roster.Count - 1)];
            GUI.Label(new Rect(30, 204, 300, 24), d.species + "   Lv." + d.level, textStyle);
            GUI.Label(new Rect(30, 228, 300, 22), "Power " + d.power + "   Bond " + d.bond, textStyle);
            GUI.Label(new Rect(30, 251, 300, 22), "Training XP " + d.xp + "/3", smallStyle);
            GUI.Label(new Rect(30, 274, 300, 22), "Next form: " + (string.IsNullOrEmpty(d.nextForm) ? "MAX" : d.nextForm), smallStyle);
            if (GUI.Button(new Rect(30, 303, 140, 30), "Train [T]", buttonStyle)) TrainActive();
            if (GUI.Button(new Rect(180, 303, 140, 30), "Evolve [U]", buttonStyle)) EvolveActive();
        }
        GUI.Box(new Rect(16, 356, 330, Mathf.Min(210, 70 + roster.Count * 22)), GUIContent.none, panelStyle);
        GUI.Label(new Rect(30, 363, 300, 26), "MONSTER COLLECTION", titleStyle);
        for (int i = 0; i < roster.Count && i < 6; i++)
            GUI.Label(new Rect(30, 389 + i * 22, 300, 22), (i == activeIndex ? "> " : "  ") + roster[i].species + " Lv." + roster[i].level, smallStyle);
        if (Time.time < statusUntil)
        {
            float y = Screen.height - 76f;
            GUI.Box(new Rect(16, y, Mathf.Min(Screen.width - 32, 700), 54), GUIContent.none, panelStyle);
            GUI.Label(new Rect(30, y + 12, Mathf.Min(Screen.width - 60, 670), 32), status, textStyle);
        }
        WildMonster near = FindNearestWild(3.2f);
        if (near != null)
            GUI.Label(new Rect(Screen.width * 0.5f - 170, Screen.height - 112, 340, 26),
                "Nearby: " + near.species + " Lv." + near.level + " | Press E to capture", titleStyle);
    }

    private void EnsureStyles()
    {
        if (titleStyle != null) return;
        titleStyle = new GUIStyle(GUI.skin.label) { fontSize = 16, fontStyle = FontStyle.Bold, normal = { textColor = new Color(0.96f, 0.83f, 0.42f) } };
        panelStyle = new GUIStyle(GUI.skin.box);
        panelStyle.normal.background = MakeTexture(new Color(0.035f, 0.07f, 0.09f, 0.91f));
        textStyle = new GUIStyle(GUI.skin.label) { fontSize = 13, normal = { textColor = Color.white } };
        smallStyle = new GUIStyle(GUI.skin.label) { fontSize = 12, normal = { textColor = new Color(0.77f, 0.86f, 0.87f) } };
        buttonStyle = new GUIStyle(GUI.skin.button) { fontSize = 12, fontStyle = FontStyle.Bold };
    }

    private static Texture2D MakeTexture(Color color)
    {
        Texture2D texture = new Texture2D(1, 1);
        texture.SetPixel(0, 0, color); texture.Apply(); return texture;
    }
}