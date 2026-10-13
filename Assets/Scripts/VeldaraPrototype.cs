using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

/// <summary>Veldara Demo 0: Caldra greybox. Original prototype, not final art.</summary>
public sealed class VeldaraPrototype : MonoBehaviour
{
    private sealed class MonsterData
    {
        public string species = "Embit (Sprout)";
        public int level = 1, hp = 100, maxHp = 100, power = 15, bond, xp, trainingSessions, evolutionStage;
        public float gauge;
        public bool bloom;
        public Color color = new Color(1f, .34f, .12f);
    }
    private sealed class Enemy : MonoBehaviour
    {
        public string species;
        public int level, hp, maxHp, power;
        public float attackTimer, seed;
        public Vector3 home;
        public Color color;
        public bool dead;
    }
    private sealed class StoryNpc : MonoBehaviour { public string npcName; }

    private readonly List<Enemy> enemies = new List<Enemy>();
    private readonly List<MonsterData> roster = new List<MonsterData>();
    private int activeMonsterIndex;
    private MonsterData ActiveMonster => roster.Count > 0 ? roster[Mathf.Clamp(activeMonsterIndex, 0, roster.Count - 1)] : embit;
    private Transform player, partner;
    private Camera cam;
    private MonsterData embit;
    private float playerHp = 100, attackCooldown, statusUntil, flash;
    private int bits = 25, questStep;
    private bool questStarted, questComplete, showDialogue = true;
    private string status = "Find Kaelen near the village forge.";
    private string speaker = "FIELD GUIDE";
    private string dialogue = "WASD move • Space attack • E talk/interact • Q Bond Shift";
    private GUIStyle title, panel, body, small, button;
    private readonly Vector3 camOffset = new Vector3(0, 10, -11);

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void Boot()
    {
        if (FindAnyObjectByType<VeldaraPrototype>() == null)
            new GameObject("Veldara Caldra Demo Runtime").AddComponent<VeldaraPrototype>();
    }
    private void Start()
    {
        Application.targetFrameRate = 60;
        RenderSettings.ambientLight = new Color(.38f,.36f,.39f);
        RenderSettings.fog = true; RenderSettings.fogColor = new Color(.30f,.25f,.24f); RenderSettings.fogDensity = .012f;
        if (FindAnyObjectByType<Light>() == null) {
            GameObject sun = new GameObject("Caldra Volcanic Light"); Light l = sun.AddComponent<Light>();
            l.type = LightType.Directional; l.intensity = 1.15f; l.color = new Color(1f,.76f,.56f);
            sun.transform.rotation = Quaternion.Euler(48,-32,0);
        }
        BuildWorld();
        player = Primitive("Tamer",PrimitiveType.Capsule,new Vector3(-3,1,5),new Vector3(.72f,1,.72f),new Color(.28f,.60f,.95f)).transform;
        MakeNpc("Kaelen Vorr",new Vector3(-11,1,10),new Color(.22f,.40f,.52f));
        MakeNpc("Tessa",new Vector3(-14,1,13),new Color(.67f,.45f,.30f));
        MakeNpc("Pip",new Vector3(-7,1,13),new Color(.73f,.69f,.53f));
        embit = new MonsterData();
        roster.Clear();
        roster.Add(embit);
        activeMonsterIndex = 0;
        SpawnPartner();
        CreateEnemy("Ashling",2,new Vector3(4,0,1),new Color(.63f,.28f,.17f),42,8);
        CreateEnemy("Cinder Mite",1,new Vector3(9,0,5),new Color(.84f,.39f,.13f),32,6);
        CreateEnemy("Ashling",3,new Vector3(4,0,-7),new Color(.63f,.28f,.17f),55,10);
        CreateEnemy("Concord Siphon",4,new Vector3(18,0,-17),new Color(.48f,.12f,.13f),120,13);
        cam=Camera.main;
        if (cam == null)
        {
            GameObject c = new GameObject("Main Camera");
            cam = c.AddComponent<Camera>();
            c.tag = "MainCamera";
            c.AddComponent<AudioListener>();
        }
        cam.fieldOfView=58; cam.backgroundColor=new Color(.30f,.25f,.26f);
        SetStatus("DEMO 0 — CALDRA: Find Kaelen at the village forge.");
    }
    private void Update()
    {
        if(player==null)return;
        Keyboard k=Keyboard.current; Vector2 move=Vector2.zero;
        if(k!=null){
            if(k.wKey.isPressed||k.upArrowKey.isPressed)move.y++;
            if(k.sKey.isPressed||k.downArrowKey.isPressed)move.y--;
            if(k.dKey.isPressed||k.rightArrowKey.isPressed)move.x++;
            if(k.aKey.isPressed||k.leftArrowKey.isPressed)move.x--;
            if(move.sqrMagnitude>1)move.Normalize();
            if(k.spaceKey.wasPressedThisFrame)Attack();
            if(k.eKey.wasPressedThisFrame)Interact();
            if(k.cKey.wasPressedThisFrame)CaptureNearest();
            if(k.tKey.wasPressedThisFrame)TrainActiveMonster();
            if(k.uKey.wasPressedThisFrame)EvolveActiveMonster();
            if(k.tabKey.wasPressedThisFrame)SwitchActiveMonster();
            if(k.qKey.wasPressedThisFrame)BondShift();
            if(k.hKey.wasPressedThisFrame){playerHp=100;ActiveMonster.hp=ActiveMonster.maxHp;SetStatus("Tamer and active monster HP restored for testing.");}
            if(k.escapeKey.wasPressedThisFrame)showDialogue=!showDialogue;
        }
        Vector3 p=player.position+new Vector3(move.x,0,move.y)*5f*Time.deltaTime;
        p.x=Mathf.Clamp(p.x,-29,29);p.z=Mathf.Clamp(p.z,-29,29);player.position=p;
        if(move.sqrMagnitude>.01f)player.rotation=Quaternion.LookRotation(new Vector3(move.x,0,move.y));
        if(partner!=null){Vector3 follow=player.position-player.right*1.15f-player.forward*.9f;partner.position=Vector3.Lerp(partner.position,new Vector3(follow.x,.7f+Mathf.Sin(Time.time*4)*.08f,follow.z),Time.deltaTime*4.5f);partner.rotation=Quaternion.Slerp(partner.rotation,Quaternion.LookRotation(player.position-partner.position),Time.deltaTime*5);}
        foreach(Enemy e in enemies){
            if(e==null||e.dead)continue;
            float d=Vector3.Distance(player.position,e.transform.position);
            if(d<8){Vector3 v=player.position-e.transform.position;v.y=0;if(d>1.7f)e.transform.position+=v.normalized*Time.deltaTime*(.65f+e.level*.08f);e.attackTimer-=Time.deltaTime;
                if(d<2&&e.attackTimer<=0){e.attackTimer=1.8f;playerHp-=e.power;flash=.2f;SetStatus(e.species+" hits you for "+e.power+".");if(playerHp<=0){playerHp=100;player.position=new Vector3(-3,1,5);SetStatus("Overwhelmed — returned to village, HP restored.");}}}
            else {float t=Time.time*.4f+e.seed;Vector3 h=e.home+new Vector3(Mathf.Sin(t)*.8f,0,Mathf.Cos(t*.8f)*.8f);e.transform.position=Vector3.Lerp(e.transform.position,h,Time.deltaTime*.5f);}
        }
        if(cam!=null){cam.transform.position=Vector3.Lerp(cam.transform.position,player.position+camOffset,Time.deltaTime*4);cam.transform.LookAt(player.position+Vector3.up*.6f);}
        attackCooldown=Mathf.Max(0,attackCooldown-Time.deltaTime);flash=Mathf.Max(0,flash-Time.deltaTime);
    }
    private void BuildWorld()
    {
        Primitive("Caldra Ash Field",PrimitiveType.Cube,new Vector3(0,-.4f,0),new Vector3(64,.7f,64),new Color(.30f,.27f,.27f));
        for(int i=0;i<40;i++){float a=i*Mathf.PI*2/40;GameObject r=Primitive("Basalt Ridge",PrimitiveType.Sphere,new Vector3(Mathf.Cos(a)*31,1,Mathf.Sin(a)*31),new Vector3(Random.Range(2f,4f),Random.Range(2f,5f),Random.Range(2f,4f)),new Color(.19f,.18f,.19f));r.transform.rotation=Quaternion.Euler(Random.Range(-12,12),Random.Range(0,180),Random.Range(-12,12));}
        for(int i=0;i<9;i++){float z=-22+i*5.3f;Primitive("Lava Fissure",PrimitiveType.Cube,new Vector3(-14,.015f,z),new Vector3(.16f,.035f,3.5f),new Color(1,.20f,.025f));Primitive("Lava Fissure",PrimitiveType.Cube,new Vector3(17,.02f,z+1.5f),new Vector3(.12f,.04f,2.8f),new Color(1,.29f,.04f));}
        Landmark("CALDRA VILLAGE",new Vector3(-12,0,12),new Color(.42f,.25f,.18f));
        Landmark("THE OLD FORGE",new Vector3(-9,0,17),new Color(.24f,.21f,.22f));
        Primitive("Forge Ember",PrimitiveType.Sphere,new Vector3(-9,1.3f,17),Vector3.one*.8f,new Color(1,.24f,.025f));
        Landmark("OLD MINE",new Vector3(17,0,9),new Color(.25f,.24f,.22f));
        Landmark("VOLCANO CRATER",new Vector3(18,0,-17),new Color(.40f,.17f,.11f));
        Landmark("COLD ANVIL",new Vector3(2,0,-11),new Color(.36f,.32f,.29f));
        for(int i=0;i<24;i++){float x=Mathf.Sin(i*7.17f)*25,z=Mathf.Cos(i*4.61f)*25;if(Vector2.Distance(new Vector2(x,z),new Vector2(-12,12))<7)continue;Primitive("Charred Tree",PrimitiveType.Cylinder,new Vector3(x,.65f,z),new Vector3(.18f,.65f,.18f),new Color(.15f,.12f,.12f));Primitive("Basalt Boulder",PrimitiveType.Sphere,new Vector3(x+1.1f,.35f,z+.7f),new Vector3(1.3f,.65f,1),new Color(.24f,.22f,.23f));}
    }
    private void Landmark(string name,Vector3 p,Color c){Primitive(name+" platform",PrimitiveType.Cylinder,p+Vector3.down*.05f,new Vector3(5,.18f,5),c);GameObject m=Primitive(name+" marker",PrimitiveType.Cube,p+Vector3.up*.9f,new Vector3(1.1f,1.8f,.8f),Color.Lerp(c,Color.white,.15f));m.transform.rotation=Quaternion.Euler(0,25,0);}
    private GameObject Primitive(string name,PrimitiveType type,Vector3 p,Vector3 s,Color c){GameObject o=GameObject.CreatePrimitive(type);o.name=name;o.transform.position=p;o.transform.localScale=s;Renderer r=o.GetComponent<Renderer>();if(r!=null){r.material.color=c;r.material.SetFloat("_Smoothness",.12f);}return o;}
    private void Child(Transform par,string name,Vector3 p,Vector3 s,Color c){GameObject o=Primitive(name,PrimitiveType.Sphere,Vector3.zero,s,c);o.transform.SetParent(par,false);o.transform.localPosition=p;Collider col=o.GetComponent<Collider>();if(col!=null)Destroy(col);}
    private void MakeNpc(string name,Vector3 p,Color c){Primitive("NPC - "+name,PrimitiveType.Capsule,p,new Vector3(.75f,1,.75f),c).AddComponent<StoryNpc>().npcName=name;}
    private void CreateEnemy(string name,int level,Vector3 p,Color c,int hp,int power){GameObject o=Primitive("Wild - "+name,PrimitiveType.Sphere,p+Vector3.up*.65f,Vector3.one*1.25f,c);Enemy e=o.AddComponent<Enemy>();e.species=name;e.level=level;e.hp=e.maxHp=hp;e.power=power;e.color=c;e.home=o.transform.position;e.seed=Random.Range(0f,10f);enemies.Add(e);Child(o.transform,"Eye L",new Vector3(-.23f,.13f,.42f),Vector3.one*.15f,Color.white);Child(o.transform,"Eye R",new Vector3(.23f,.13f,.42f),Vector3.one*.15f,Color.white);}
    private void SpawnPartner()
    {
        if (partner != null) Destroy(partner.gameObject);
        MonsterData active = ActiveMonster;
        GameObject o = Primitive("Partner - " + active.species, PrimitiveType.Sphere,
            player.position + new Vector3(-1, 0, -1), Vector3.one * .85f, active.color);
        partner = o.transform;
        Child(partner, "Ember Core", new Vector3(0, .05f, .38f), Vector3.one * .24f, new Color(1, .82f, .22f));
        Child(partner, "Eye L", new Vector3(-.2f, .14f, .34f), Vector3.one * .12f, Color.white);
        Child(partner, "Eye R", new Vector3(.2f, .14f, .34f), Vector3.one * .12f, Color.white);
        Collider col = o.GetComponent<Collider>();
        if (col != null) Destroy(col);
    }
    private Enemy NearestEnemy(float range){Enemy best=null;float dBest=range;foreach(Enemy e in enemies){if(e==null||e.dead)continue;float d=Vector3.Distance(player.position,e.transform.position);if(d<dBest){best=e;dBest=d;}}return best;}
    private void Attack()
    {
        if (attackCooldown > 0) return;
        attackCooldown = .48f;
        Enemy e = NearestEnemy(3.2f);
        if (e == null) { SetStatus("No enemy in range — move closer."); return; }
        MonsterData active = ActiveMonster;
        int dmg = active.power + (active.bloom ? 8 : 0);
        e.hp -= dmg;
        active.gauge = Mathf.Min(100, active.gauge + 18);
        active.bond++;
        SetStatus(active.species + " hits " + e.species + " for " + dmg + " damage. Bond +18.");
        if (e.hp <= 0)
        {
            e.dead = true;
            e.gameObject.SetActive(false);
            bits += 5;
            active.gauge = Mathf.Min(100, active.gauge + 12);
            GainExperience(active, e.level * 8 + 5);
            SetStatus(e.species + " defeated. +5 bits and experience.");
            if (e.species == "Concord Siphon")
            {
                SetStatus("Siphon destroyed! Return to Kaelen at the forge.");
                if (questStarted) questStep = 2;
            }
        }
    }
    private StoryNpc NearestNpc(float range){StoryNpc best=null;float dBest=range;foreach(StoryNpc n in FindObjectsByType<StoryNpc>()){if(n==null)continue;float d=Vector3.Distance(player.position,n.transform.position);if(d<dBest){best=n;dBest=d;}}return best;}
    private void Interact(){StoryNpc n=NearestNpc(3.2f);if(n!=null){Talk(n.npcName);return;}Enemy e=NearestEnemy(3);if(e!=null){SetStatus(e.species+" Lv."+e.level+" HP "+e.hp+"/"+e.maxHp+" — Space to attack, C to attempt capture.");return;}if(Vector3.Distance(player.position,new Vector3(-9,0,17))<5){playerHp=100;ActiveMonster.hp=ActiveMonster.maxHp;SetStatus("Rested at the forge. HP restored.");return;}SetStatus("Nothing nearby. Find Kaelen, Tessa or Pip in the village.");}
    private void Talk(string name){speaker=name.ToUpperInvariant();showDialogue=true;if(name=="Kaelen Vorr"){if(!questStarted){questStarted=true;questStep=1;dialogue="The ash moves against the wind. Take Embit and destroy the Concord siphon near the crater before it drains the hot spring.";SetStatus("Quest started: A Forge Gone Quiet.");}else if(questStep==2){questStep=3;dialogue="You returned. This machine is only a fragment. Take an Ember Whetstone and a Forge Core; both may shape Embit's future.";}else if(questStep==3){questStep=4;questComplete=true;dialogue="The core hums. The Concord is extracting power from the Guardian. When your Bond is full, Q awakens Embit's Bloom form.";SetStatus("QUEST COMPLETE: A Forge Gone Quiet.");}else if(questComplete)dialogue="The forge is safe for now. Nine distant pillars still flicker beyond Caldra.";else dialogue="The siphon waits near the crater. Keep Embit close and attack with Space.";}else if(name=="Tessa")dialogue=questComplete?"The Forge Core hums like it remembers a voice.":"Concord machines take more than heat. They drain the bond between a creature and this world.";else dialogue=questComplete?"Kaelen says the egg can be saved. I heard it tapping inside the forge!":"I found a warm egg near the forge. Something inside keeps answering the volcano.";SetStatus(name+": "+dialogue);}
    private void BondShift()
    {
        if (!questComplete) { SetStatus("Bond Shift is unstable. Finish Kaelen's quest first."); return; }
        if (ActiveMonster != embit)
        {
            activeMonsterIndex = roster.IndexOf(embit);
            SpawnPartner();
        }
        if (!embit.bloom)
        {
            if (embit.gauge < 100) { SetStatus("Bond Gauge " + Mathf.RoundToInt(embit.gauge) + "/100. Fight enemies to build it."); return; }
            embit.bloom = true;
            embit.species = "Embit (Bloom)";
            embit.power += 8;
            embit.maxHp += 35;
            embit.hp = embit.maxHp;
            embit.color = new Color(1, .58f, .16f);
            SpawnPartner();
            SetStatus("BOND SHIFT! Embit awakens Bloom. Captured monsters have their own evolution paths.");
        }
        else
        {
            embit.bloom = false;
            embit.species = "Embit (Sprout)";
            embit.power = Mathf.Max(15, embit.power - 8);
            embit.color = new Color(1, .34f, .12f);
            SpawnPartner();
            SetStatus("Embit returned to Sprout. Bond Gauge preserved.");
        }
    }
    private void CaptureNearest()
    {
        Enemy target = NearestEnemy(3.2f);
        if (target == null) { SetStatus("Move within 3.2m of a wild monster to capture it."); return; }
        if (target.species == "Concord Siphon")
        {
            SetStatus("The Concord Siphon is a boss machine and cannot be captured.");
            return;
        }
        if (roster.Count >= 6) { SetStatus("Monster roster full (6/6). Release or manage a monster first."); return; }
        const int captureCost = 5;
        if (bits < captureCost) { SetStatus("Capture requires " + captureCost + " bits."); return; }
        bits -= captureCost;
        float missingHp = 1f - Mathf.Clamp01(target.hp / (float)target.maxHp);
        float levelPenalty = Mathf.Max(0, target.level - ActiveMonster.level) * 8f;
        float chance = Mathf.Clamp(35f + missingHp * 45f - levelPenalty, 10f, 90f);
        if (Random.Range(0f, 100f) <= chance)
        {
            MonsterData caught = new MonsterData
            {
                species = target.species,
                level = target.level,
                hp = target.maxHp,
                maxHp = target.maxHp,
                power = target.power,
                color = target.color,
                xp = 0
            };
            roster.Add(caught);
            target.dead = true;
            target.gameObject.SetActive(false);
            enemies.Remove(target);
            SetStatus("Captured " + caught.species + " Lv." + caught.level + "! Chance was " + Mathf.RoundToInt(chance) + "%. Roster " + roster.Count + "/6.");
        }
        else
        {
            SetStatus("Capture failed (" + Mathf.RoundToInt(chance) + "%). Target weakened; try again.");
        }
    }

    private void TrainActiveMonster()
    {
        MonsterData active = ActiveMonster;
        const int cost = 3;
        if (bits < cost) { SetStatus("Training costs " + cost + " bits."); return; }
        bits -= cost;
        active.trainingSessions++;
        GainExperience(active, 12);
        active.hp = Mathf.Min(active.maxHp, active.hp + 8);
        SetStatus(active.species + " trained. +12 EXP, +8 HP, -" + cost + " bits. Session " + active.trainingSessions + ".");
    }

    private void GainExperience(MonsterData monster, int amount)
    {
        if (monster == null || amount <= 0) return;
        monster.xp += amount;
        while (monster.xp >= monster.level * 25)
        {
            monster.xp -= monster.level * 25;
            monster.level++;
            monster.maxHp += 8;
            monster.power += 2;
            monster.hp = monster.maxHp;
            SetStatus(monster.species + " reached Lv." + monster.level + "! Max HP +8, Power +2.");
        }
    }

    private void EvolveActiveMonster()
    {
        MonsterData active = ActiveMonster;
        if (active == embit)
        {
            SetStatus("Embit evolves through the story Bond Shift (Q), not ordinary evolution.");
            return;
        }
        if (active.level < 5) { SetStatus(active.species + " needs Lv.5 to evolve (currently Lv." + active.level + ")."); return; }
        string nextSpecies = null;
        Color nextColor = active.color;
        if (active.species == "Ashling" && active.evolutionStage == 0)
        {
            nextSpecies = "Cindermaw";
            nextColor = new Color(.78f, .22f, .12f);
        }
        else if (active.species == "Cindermaw" && active.evolutionStage == 1 && active.level >= 10)
        {
            nextSpecies = "Pyroclast";
            nextColor = new Color(1f, .36f, .08f);
        }
        else if (active.species == "Cinder Mite" && active.evolutionStage == 0)
        {
            nextSpecies = "Emberwing";
            nextColor = new Color(.96f, .48f, .12f);
        }
        else if (active.species == "Emberwing" && active.evolutionStage == 1 && active.level >= 10)
        {
            nextSpecies = "Solwing";
            nextColor = new Color(1f, .72f, .20f);
        }
        if (nextSpecies == null)
        {
            SetStatus(active.species + " has no available evolution at this level, or needs Lv.10 for its final stage.");
            return;
        }
        active.species = nextSpecies;
        active.evolutionStage++;
        active.maxHp += 20;
        active.power += 5;
        active.hp = active.maxHp;
        active.color = nextColor;
        SpawnPartner();
        SetStatus("EVOLUTION! Your monster became " + nextSpecies + ". Max HP +20, Power +5.");
    }

    private void SwitchActiveMonster()
    {
        if (roster.Count < 2) { SetStatus("Capture another monster before switching partners."); return; }
        activeMonsterIndex = (activeMonsterIndex + 1) % roster.Count;
        SpawnPartner();
        SetStatus("Active partner: " + ActiveMonster.species + " Lv." + ActiveMonster.level + ".");
    }

    private void SetStatus(string s){status=s;statusUntil=Time.time+7;Debug.Log("[Veldara Caldra] "+s);}
    private void OnGUI(){Styles();MonsterData activeMonster = ActiveMonster;GUI.Box(new Rect(14,14,360,140),GUIContent.none,panel);GUI.Label(new Rect(28,20,330,28),"VELDARA / CALDRA ARC",title);GUI.Label(new Rect(28,51,90,22),"TAMER HP",small);Bar(new Rect(118,54,235,14),playerHp/100,new Color(.78f,.22f,.18f));GUI.Label(new Rect(28,75,90,22),"PARTNER HP",small);Bar(new Rect(118,78,235,14),ActiveMonster.hp/(float)ActiveMonster.maxHp,ActiveMonster.color);GUI.Label(new Rect(28,103,330,22),"Bond Gauge "+Mathf.RoundToInt(activeMonster.gauge)+"/100",body);Bar(new Rect(28,128,325,10),activeMonster.gauge/100,new Color(.94f,.66f,.22f));
    GUI.Box(new Rect(14,164,360,132),GUIContent.none,panel);GUI.Label(new Rect(28,170,330,25),activeMonster.species.ToUpperInvariant(),title);GUI.Label(new Rect(28,200,330,22),"Lv."+activeMonster.level+"  Power "+activeMonster.power+"  Bond "+activeMonster.bond+"  EXP "+activeMonster.xp+"/"+(activeMonster.level*25),body);GUI.Label(new Rect(28,225,330,22),"Bits: "+bits+"  Team: "+roster.Count+"/6  Quest: "+(questComplete?"COMPLETE":questStarted?"IN PROGRESS":"NOT STARTED"),small);if(GUI.Button(new Rect(28,255,150,30),"Bond Shift [Q]",button))BondShift();if(GUI.Button(new Rect(190,255,160,30),"Rest [H]",button)){playerHp=100;activeMonster.hp=activeMonster.maxHp;SetStatus("HP restored.");}
    GUI.Box(new Rect(14,306,360,112),GUIContent.none,panel);GUI.Label(new Rect(28,312,330,24),"FIELD CONTROLS",title);GUI.Label(new Rect(28,340,330,20),"WASD move • Space attack • E interact",small);GUI.Label(new Rect(28,362,330,20),"C capture • T train • U evolve • Tab switch",small);GUI.Label(new Rect(28,384,330,20),"Q Bond Shift • H rest • Find Kaelen.",small);
    GUI.Box(new Rect(Screen.width-300,14,286,125),GUIContent.none,panel);GUI.Label(new Rect(Screen.width-284,20,260,25),"CALDRA FIELD NOTES",title);GUI.Label(new Rect(Screen.width-284,49,260,20),"Village / Old Forge [NW]",small);GUI.Label(new Rect(Screen.width-284,71,260,20),"Old Mine [E]",small);GUI.Label(new Rect(Screen.width-284,93,260,20),"Volcano Crater [SE]",small);
    GUI.Box(new Rect(Screen.width-300,148,286,180),GUIContent.none,panel);
    GUI.Label(new Rect(Screen.width-284,154,260,22),"MONSTER ROSTER",title);
    GUI.Label(new Rect(Screen.width-284,179,260,42),"Active: "+activeMonster.species+" Lv."+activeMonster.level+"\nHP "+activeMonster.hp+"/"+activeMonster.maxHp+" • Power "+activeMonster.power,small);
    GUI.Label(new Rect(Screen.width-284,222,260,20),"Owned: "+roster.Count+"/6 • Capture cost: 5 bits",small);
    if(GUI.Button(new Rect(Screen.width-284,247,124,28),"Capture [C]",button))CaptureNearest();
    if(GUI.Button(new Rect(Screen.width-152,247,124,28),"Train [T]",button))TrainActiveMonster();
    if(GUI.Button(new Rect(Screen.width-284,280,124,28),"Evolve [U]",button))EvolveActiveMonster();
    if(GUI.Button(new Rect(Screen.width-152,280,124,28),"Switch [Tab]",button))SwitchActiveMonster();
    if(showDialogue){float y=Screen.height-152;GUI.Box(new Rect(14,y,Mathf.Min(Screen.width-28,760),136),GUIContent.none,panel);GUI.Label(new Rect(30,y+8,700,24),speaker,title);GUI.Label(new Rect(30,y+36,Mathf.Min(Screen.width-60,700),62),dialogue,body);if(GUI.Button(new Rect(30,y+99,110,27),"Close [Esc]",button))showDialogue=false;}if(Time.time<statusUntil){GUI.Box(new Rect(Screen.width*.30f,Screen.height-46,Screen.width*.40f,34),GUIContent.none,panel);GUI.Label(new Rect(Screen.width*.30f+10,Screen.height-41,Screen.width*.40f-20,25),status,small);}if(flash>0)GUI.Box(new Rect(0,0,Screen.width,Screen.height),GUIContent.none,new GUIStyle{normal={background=Tex(new Color(.8f,.05f,.02f,flash*2))}});}
    private void Bar(Rect r,float v,Color c){GUI.Box(r,GUIContent.none);Color old=GUI.color;GUI.color=c;GUI.DrawTexture(new Rect(r.x+2,r.y+2,Mathf.Max(0,(r.width-4)*Mathf.Clamp01(v)),r.height-4),Texture2D.whiteTexture);GUI.color=old;}
    private void Styles(){if(title!=null)return;title=new GUIStyle(GUI.skin.label){fontSize=15,fontStyle=FontStyle.Bold,normal={textColor=new Color(1,.76f,.37f)}};panel=new GUIStyle(GUI.skin.box){normal={background=Tex(new Color(.035f,.045f,.055f,.91f))}};body=new GUIStyle(GUI.skin.label){fontSize=13,wordWrap=true,normal={textColor=Color.white}};small=new GUIStyle(GUI.skin.label){fontSize=11,wordWrap=true,normal={textColor=new Color(.78f,.83f,.85f)}};button=new GUIStyle(GUI.skin.button){fontSize=11,fontStyle=FontStyle.Bold};}
    private static Texture2D Tex(Color c){Texture2D t=new Texture2D(1,1);t.SetPixel(0,0,c);t.Apply();return t;}
}
