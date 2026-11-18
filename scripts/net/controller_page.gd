## The phone controller: one self-contained HTML page (no external files, no libraries) served by
## NetServer at "/". It talks to PhoneHub over a WebSocket at "/ws" with small JSON messages
## (protocol in phone_hub.gd), keeps a permanent phone id and the player's name in localStorage so
## a refresh or a dropped Wi-Fi puts the phone back in its slot, and reconnects every 2 s.
##
## Screens: join (name) -> lobby (pick a runner, READY) -> game (swipe pad + arrow buttons,
## score / lives / place, 3-2-1, red flash and vibration on hits) -> results (place, table,
## PLAY AGAIN). Texts in English, Uzbek and Russian (the computer's language).
class_name ControllerPage
extends RefCounted


static func html() -> String:
	return PAGE


const PAGE: String = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<meta name="theme-color" content="#2a1a10">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<title>Jura Rush</title>
<style>
:root{--bg:#2a1a10;--panel:#3b2719;--panel2:#4b3322;--line:#1a0f08;--text:#fff7e6;--dim:#cdb898;--accent:#ffa31f;--green:#6bbd33;--red:#e6482a;--me:#ffa31f}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent;user-select:none;-webkit-user-select:none}
html,body{margin:0;height:100%;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif;overscroll-behavior:none}
body{background:linear-gradient(#3a2416,#1e120a);display:flex;flex-direction:column}
header{display:flex;align-items:center;justify-content:space-between;padding:10px 14px;padding-top:max(10px,env(safe-area-inset-top))}
.logo{font-weight:900;font-size:22px;letter-spacing:1px;color:var(--accent);text-shadow:0 3px 0 var(--line)}
.net{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--dim)}
.dot{width:11px;height:11px;border-radius:50%;background:var(--red);box-shadow:0 0 0 2px var(--line)}
.dot.on{background:var(--green)}
main{flex:1;display:flex;flex-direction:column;min-height:0}
.screen{display:none;flex:1;flex-direction:column;padding:12px 16px 18px;gap:14px;min-height:0}
.screen.show{display:flex}
h1{margin:6px 0 0;font-size:28px;font-weight:900;text-align:center;text-shadow:0 3px 0 var(--line)}
.hint{color:var(--dim);text-align:center;font-size:15px;line-height:1.35}
.big{font-size:22px;text-align:center;font-weight:800;line-height:1.35;margin:auto 0}
input{font:inherit;font-size:22px;font-weight:700;padding:14px 16px;border-radius:16px;border:4px solid var(--line);background:#fff7e6;color:#2a1a10;width:100%;user-select:text;-webkit-user-select:text}
button{font:inherit;font-weight:900;font-size:22px;letter-spacing:.5px;color:var(--text);background:var(--green);border:4px solid var(--line);border-bottom-width:9px;border-radius:18px;padding:14px 18px;text-shadow:0 2px 0 rgba(0,0,0,.35);touch-action:manipulation}
button:active{border-bottom-width:4px;transform:translateY(5px)}
button:disabled{background:#7b6f60;color:#d8cfc0}
button.ready{background:var(--accent)}
button.stone{background:#9e8f7a}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;overflow-y:auto;padding:2px}
.card{position:relative;background:var(--panel);border:4px solid var(--line);border-radius:18px;padding:10px 4px 8px;display:flex;flex-direction:column;align-items:center;gap:6px;touch-action:manipulation}
.card .face{width:58px;height:58px;border-radius:50%;border:4px solid var(--line);display:flex;align-items:center;justify-content:center;font-weight:900;font-size:24px;color:#fff;text-shadow:0 2px 0 var(--line)}
.card .nm{font-weight:800;font-size:15px}
.card .tag{font-size:11px;font-weight:900;padding:2px 7px;border-radius:9px;background:var(--line);color:var(--dim);min-height:17px}
.card .tag:empty{visibility:hidden}
.card.mine{border-color:var(--me);box-shadow:0 0 0 3px var(--me) inset}
.card.mine .tag{background:var(--me);color:#2a1a10}
.card.taken{opacity:.45}
.chips{display:flex;gap:8px;justify-content:center;flex-wrap:wrap}
.chip{display:flex;align-items:center;gap:6px;padding:6px 10px;border-radius:14px;background:var(--panel);border:3px solid var(--line);font-weight:800;font-size:15px}
.chip i{width:12px;height:12px;border-radius:50%;display:inline-block;border:2px solid var(--line)}
.me{display:flex;align-items:center;justify-content:center;gap:10px;font-weight:900;font-size:20px}
.me span{padding:6px 14px;border-radius:14px;border:4px solid var(--line);background:var(--me);color:#2a1a10}
.bar{display:flex;justify-content:space-between;align-items:center;gap:8px;background:var(--panel);border:4px solid var(--line);border-radius:18px;padding:8px 12px}
.stat{display:flex;flex-direction:column;align-items:center;min-width:64px}
.stat b{font-size:24px;font-weight:900}
.stat small{font-size:11px;color:var(--dim);font-weight:800;text-transform:uppercase}
.hearts{font-size:22px;letter-spacing:2px}
#pad{position:relative;flex:1;min-height:180px;border-radius:24px;border:4px dashed rgba(255,247,230,.25);background:rgba(0,0,0,.18);touch-action:none;display:flex;align-items:center;justify-content:center;overflow:hidden}
#pad .cross{font-size:20px;color:rgba(255,247,230,.35);text-align:center;line-height:1.6;font-weight:800;pointer-events:none}
#pad .flash{position:absolute;font-size:96px;font-weight:900;color:var(--accent);opacity:0;pointer-events:none;text-shadow:0 5px 0 var(--line)}
#pad .flash.go{animation:pop .35s ease-out}
.arrows{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}
.arrows button{font-size:34px;padding:12px 0;background:#9e8f7a}
.overlay{position:absolute;inset:0;display:none;align-items:center;justify-content:center;flex-direction:column;gap:8px;background:rgba(20,12,6,.72);text-align:center;padding:16px;font-weight:900;font-size:26px}
.overlay.show{display:flex}
.overlay small{font-size:15px;color:var(--dim);font-weight:700}
#count{font-size:150px;color:var(--accent);text-shadow:0 8px 0 var(--line)}
#count.pop{animation:pop .5s ease-out}
@keyframes pop{0%{transform:scale(.4);opacity:0}40%{transform:scale(1.15);opacity:1}100%{transform:scale(1);opacity:1}}
.medal{font-size:96px;text-align:center;line-height:1}
.rows{display:flex;flex-direction:column;gap:8px}
.row{display:flex;align-items:center;gap:10px;background:var(--panel);border:4px solid var(--line);border-radius:16px;padding:8px 12px;font-weight:800}
.row i{width:14px;height:14px;border-radius:50%;border:2px solid var(--line)}
.row .sc{margin-left:auto;font-size:20px;font-weight:900;color:var(--accent)}
.row.mine{box-shadow:0 0 0 3px var(--me) inset}
#edge{position:fixed;inset:0;pointer-events:none;box-shadow:inset 0 0 0 0 var(--red);transition:box-shadow .25s}
#edge.hit{box-shadow:inset 0 0 60px 26px var(--red);transition:none}
.spacer{flex:1}
</style>
</head>
<body>
<header><div class="logo">JURA RUSH</div><div class="net"><span id="netText"></span><div id="dot" class="dot"></div></div></header>
<main>
<section id="s-join" class="screen">
  <h1 id="tJoin"></h1>
  <div class="spacer"></div>
  <input id="name" maxlength="14" autocomplete="off" autocapitalize="words" enterkeyhint="go">
  <button id="joinBtn"></button>
  <div id="joinNote" class="hint"></div>
  <div class="spacer"></div>
</section>
<section id="s-wait" class="screen"><div id="waitText" class="big"></div></section>
<section id="s-lobby" class="screen">
  <div class="me"><span id="meName"></span></div>
  <div id="tPick" class="hint"></div>
  <div id="grid" class="grid"></div>
  <div id="chips" class="chips"></div>
  <div class="spacer"></div>
  <button id="readyBtn"></button>
  <div id="readyNote" class="hint"></div>
</section>
<section id="s-game" class="screen">
  <div class="bar">
    <div class="stat"><b id="gPlace">-</b><small id="tPlace"></small></div>
    <div class="stat"><b id="gScore">0</b><small id="tScore"></small></div>
    <div class="stat"><b id="gTime">0:00</b><small id="tTime"></small></div>
    <div class="hearts" id="gLives"></div>
  </div>
  <div id="pad"><div class="cross" id="tSwipe"></div><div id="flash" class="flash"></div>
    <div id="ovCount" class="overlay"><div id="count"></div></div>
    <div id="ovMsg" class="overlay"><div id="msgBig"></div><small id="msgSmall"></small></div>
  </div>
  <div class="arrows">
    <button data-a="l">&#9664;</button><button data-a="u">&#9650;</button><button data-a="d">&#9660;</button><button data-a="r">&#9654;</button>
  </div>
</section>
<section id="s-results" class="screen">
  <div id="medal" class="medal"></div>
  <h1 id="rPlace"></h1>
  <div id="rows" class="rows"></div>
  <div class="spacer"></div>
  <button id="againBtn"></button>
  <div id="againNote" class="hint"></div>
</section>
</main>
<div id="edge"></div>
<script>
"use strict";
var L={
en:{connecting:"Connecting...",online:"Connected to the game",offline:"No connection to the game. Retrying...",join:"Join the game",namePh:"Your name",joinBtn:"JOIN",full:"The room is full: three players are already in.",round:"A round is running. You can join after it.",pick:"Pick your runner (tap a card)",yours:"YOURS",taken:"TAKEN",ready:"READY",notReady:"Press READY when you are set",waiting:"Waiting for the others...",rename:"Your name",swipe:"Swipe anywhere here<br>&#8592; &#8594; change lane<br>&#8593; jump &#8195; &#8595; roll",score:"Score",place:"Place",time:"Time",out:"You are out!",outHint:"Watch the others finish",paused:"PAUSED",ready2:"Get ready!",go:"GO!",again:"PLAY AGAIN",crash:"CRASH!",places:["1st place","2nd place","3rd place"],offline2:"Phone lost. Get it back online to continue."},
uz:{connecting:"Ulanmoqda...",online:"O'yinga ulandi",offline:"O'yin bilan aloqa yo'q. Qayta urinilmoqda...",join:"O'yinga qo'shilish",namePh:"Ismingiz",joinBtn:"QO'SHILISH",full:"Xona to'la: uchta o'yinchi allaqachon bor.",round:"Raund ketmoqda. Undan keyin qo'shila olasiz.",pick:"Yuguruvchini tanlang (kartani bosing)",yours:"SENIKI",taken:"BAND",ready:"TAYYOR",notReady:"Tayyor bo'lsangiz TAYYOR ni bosing",waiting:"Boshqalar kutilmoqda...",rename:"Ismingiz",swipe:"Shu yerda suring<br>&#8592; &#8594; yo'lak almashtirish<br>&#8593; sakrash &#8195; &#8595; dumalash",score:"Hisob",place:"O'rin",time:"Vaqt",out:"Siz chiqdingiz!",outHint:"Boshqalarni tomosha qiling",paused:"PAUZA",ready2:"Tayyorlaning!",go:"OLG'A!",again:"YANA O'YNASH",crash:"URILDI!",places:["1-o'rin","2-o'rin","3-o'rin"],offline2:"Telefon uzildi. Davom etish uchun qayta ulang."},
ru:{connecting:"Подключение...",online:"Подключено к игре",offline:"Нет связи с игрой. Переподключение...",join:"Присоединиться к игре",namePh:"Ваше имя",joinBtn:"ВОЙТИ",full:"Мест нет: уже играют трое.",round:"Идёт раунд. Можно присоединиться после него.",pick:"Выберите бегуна (нажмите на карточку)",yours:"ВАШ",taken:"ЗАНЯТ",ready:"ГОТОВ",notReady:"Нажмите ГОТОВ, когда будете готовы",waiting:"Ждём остальных...",rename:"Ваше имя",swipe:"Свайпайте здесь<br>&#8592; &#8594; смена полосы<br>&#8593; прыжок &#8195; &#8595; кувырок",score:"Очки",place:"Место",time:"Время",out:"Вы выбыли!",outHint:"Смотрите, как финишируют остальные",paused:"ПАУЗА",ready2:"Приготовьтесь!",go:"ВПЕРЁД!",again:"ЕЩЁ РАЗ",crash:"УДАР!",places:["1 место","2 место","3 место"],offline2:"Телефон отключился. Подключитесь снова, чтобы продолжить."}
};
var lang=(navigator.language||"en").slice(0,2);if(!L[lang])lang="en";
function t(k){var d=L[lang]||L.en;return d[k]!==undefined?d[k]:L.en[k];}
function $(id){return document.getElementById(id);}
function store(k,v){try{if(v===undefined)return localStorage.getItem(k);localStorage.setItem(k,v);}catch(e){return null;}return null;}
var cid=store("jr_cid");if(!cid){cid=Math.random().toString(36).slice(2,10)+Date.now().toString(36);store("jr_cid",cid);}
var myName=store("jr_name")||"";
var ws=null,online=false,full=false,phase="",you=null,players=[],chars=[],tick={},results=null,againSent=false,lastCount=-1;
function send(o){if(ws&&ws.readyState===1){try{ws.send(JSON.stringify(o));}catch(e){}}}
function connect(){
  try{ws=new WebSocket("ws://"+location.host+"/ws");}catch(e){setTimeout(connect,2000);return;}
  ws.onopen=function(){online=true;send({t:"hello",cid:cid,name:myName});render();};
  ws.onmessage=function(e){var m;try{m=JSON.parse(e.data);}catch(x){return;}onMsg(m);};
  ws.onclose=function(){online=false;ws=null;render();setTimeout(connect,2000);};
  ws.onerror=function(){try{ws.close();}catch(x){}};
}
function onMsg(m){
  if(m.t==="welcome"){if(L[m.lang])lang=m.lang;chars=m.chars||[];texts();}
  else if(m.t==="state"){phase=m.phase;you=m.you;players=m.players||[];if(you){full=false;if(you.name){myName=you.name;store("jr_name",myName);}}if(phase!=="results"){againSent=false;results=null;}if(phase==="lobby"){tick={};}}
  else if(m.t==="full"){full=true;}
  else if(m.t==="tick"){tick=m;}
  else if(m.t==="count"){showCount(m.n);}
  else if(m.t==="buzz"){buzz(m.k);}
  else if(m.t==="results"){results=m;}
  render();
}
function show(id){var s=document.querySelectorAll(".screen");for(var i=0;i<s.length;i++)s[i].classList.toggle("show",s[i].id===id);}
function texts(){
  document.documentElement.lang=lang;
  $("tJoin").textContent=t("join");$("name").placeholder=t("namePh");$("joinBtn").textContent=t("joinBtn");
  $("tPick").textContent=t("pick");$("tSwipe").innerHTML=t("swipe");$("tScore").textContent=t("score");
  $("tPlace").textContent=t("place");$("tTime").textContent=t("time");$("againBtn").textContent=t("again");
}
function render(){
  $("dot").classList.toggle("on",online);$("netText").textContent=online?t("online"):t("offline");
  if(you&&you.color)document.documentElement.style.setProperty("--me",you.color);
  if(!online){show("s-join");$("joinBtn").disabled=true;$("joinNote").textContent=t("offline");return;}
  if(!you){
    if(phase==="lobby"){show("s-join");$("joinBtn").disabled=false;$("joinNote").textContent=full?t("full"):"";if(!$("name").value)$("name").value=myName;}
    else{show("s-wait");$("waitText").textContent=full?t("full"):(phase?t("round"):t("connecting"));}
    return;
  }
  if(phase==="lobby"){renderLobby();show("s-lobby");}
  else if(phase==="game"||phase==="paused"){renderGame();show("s-game");}
  else if(phase==="results"){renderResults();show("s-results");}
  else{show("s-wait");$("waitText").textContent=t("connecting");}
}
function renderLobby(){
  $("meName").textContent=you.name;
  var g=$("grid");g.innerHTML="";
  for(var i=0;i<chars.length;i++){
    var c=chars[i],owner=null;
    for(var j=0;j<players.length;j++)if(players[j].char===c.id)owner=players[j];
    var mine=owner&&owner.slot===you.slot,taken=owner&&!mine;
    var d=document.createElement("div");d.className="card"+(mine?" mine":"")+(taken?" taken":"");
    var f=document.createElement("div");f.className="face";f.style.background=c.body;f.style.borderColor=taken?owner.color:"#1a0f08";f.textContent=(c.name||"?").charAt(0);
    var n=document.createElement("div");n.className="nm";n.textContent=c.name;
    var tg=document.createElement("div");tg.className="tag";tg.textContent=mine?t("yours"):(taken?t("taken"):"");
    d.appendChild(f);d.appendChild(n);d.appendChild(tg);
    if(!taken)d.addEventListener("click",(function(id){return function(){send({t:"pick",c:id});};})(c.id));
    g.appendChild(d);
  }
  var ch=$("chips");ch.innerHTML="";
  for(var k=0;k<players.length;k++){var p=players[k];var e=document.createElement("div");e.className="chip";
    var dot=document.createElement("i");dot.style.background=p.color;e.appendChild(dot);
    e.appendChild(document.createTextNode(p.name+(p.ready?" ✓":"")));ch.appendChild(e);}
  var b=$("readyBtn");b.textContent=t("ready")+(you.ready?" ✓":"");b.className=you.ready?"ready":"";
  $("readyNote").textContent=you.ready?t("waiting"):t("notReady");
}
function fmt(s){s=Math.max(0,s|0);var m=Math.floor(s/60),r=s%60;return m+":"+(r<10?"0":"")+r;}
function renderGame(){
  $("gScore").textContent=(tick.score||0).toLocaleString();
  $("gPlace").textContent=tick.place?(tick.place+"/"+tick.players):"-";
  $("gTime").textContent=fmt(tick.time||0);
  var h="",lv=tick.lives===undefined?3:tick.lives;for(var i=0;i<3;i++)h+=i<lv?"❤️":"\u{1F5A4}";$("gLives").textContent=h;
  var ov=$("ovMsg"),big="",small="";
  if(phase==="paused"){big=t("paused");}
  else if(tick.out){big=t("out");small=t("outHint");}
  else if(tick.state==="crashed"){big=t("crash");}
  ov.classList.toggle("show",big!=="");$("msgBig").textContent=big;$("msgSmall").textContent=small;
}
function renderResults(){
  var place=0,rows=$("rows");rows.innerHTML="";
  if(results&&results.list){for(var i=0;i<results.list.length;i++){var r=results.list[i];if(r.slot===you.slot)place=r.place;
    var d=document.createElement("div");d.className="row"+(r.slot===you.slot?" mine":"");
    var dot=document.createElement("i");dot.style.background=r.color;d.appendChild(dot);
    d.appendChild(document.createTextNode(r.place+". "+r.name));
    var sc=document.createElement("span");sc.className="sc";sc.textContent=(r.score||0).toLocaleString();d.appendChild(sc);rows.appendChild(d);}}
  $("medal").textContent=place>=1&&place<=3?["\u{1F947}","\u{1F948}","\u{1F949}"][place-1]:"\u{1F3C1}";
  $("rPlace").textContent=place>=1&&place<=3?t("places")[place-1]:"";
  $("againBtn").disabled=againSent;$("againNote").textContent=againSent?t("waiting"):"";
}
function showCount(n){
  var ov=$("ovCount"),c=$("count");
  if(n<0){ov.classList.remove("show");return;}
  c.textContent=n>0?n:t("go");ov.classList.add("show");c.classList.remove("pop");void c.offsetWidth;c.classList.add("pop");
  if(n<=0)setTimeout(function(){ov.classList.remove("show");},600);
  if(navigator.vibrate)navigator.vibrate(n>0?30:80);
}
function buzz(k){
  var e=$("edge");e.classList.add("hit");setTimeout(function(){e.classList.remove("hit");},90);
  if(navigator.vibrate)navigator.vibrate(k==="crash"?[220,80,220]:120);
}
var GLYPH={l:"◀",r:"▶",u:"▲",d:"▼"};
function act(a){send({t:"in",a:a});var f=$("flash");f.textContent=GLYPH[a];f.classList.remove("go");void f.offsetWidth;f.classList.add("go");}
(function(){
  var pad=$("pad"),start=null;
  function th(){return Math.max(22,Math.min(innerWidth,innerHeight)*0.06);}
  pad.addEventListener("pointerdown",function(e){start={x:e.clientX,y:e.clientY,id:e.pointerId};try{pad.setPointerCapture(e.pointerId);}catch(x){}e.preventDefault();});
  pad.addEventListener("pointermove",function(e){
    if(!start||e.pointerId!==start.id)return;
    var dx=e.clientX-start.x,dy=e.clientY-start.y,ax=Math.abs(dx),ay=Math.abs(dy),m=th();
    if(ax>=m&&ax>ay*1.2){act(dx>0?"r":"l");start.x=e.clientX;start.y=e.clientY;}
    else if(ay>=m&&ay>ax*1.2){act(dy<0?"u":"d");start.x=e.clientX;start.y=e.clientY;}
    e.preventDefault();
  });
  function end(e){if(start&&e.pointerId===start.id)start=null;}
  pad.addEventListener("pointerup",end);pad.addEventListener("pointercancel",end);
  var bs=document.querySelectorAll(".arrows button");
  for(var i=0;i<bs.length;i++)bs[i].addEventListener("pointerdown",function(e){act(this.getAttribute("data-a"));e.preventDefault();});
})();
$("joinBtn").addEventListener("click",function(){var n=$("name").value.trim();if(n){myName=n;store("jr_name",n);}send({t:"join",name:myName});});
$("name").addEventListener("keydown",function(e){if(e.key==="Enter")$("joinBtn").click();});
$("readyBtn").addEventListener("click",function(){if(you)send({t:"ready",v:!you.ready});});
$("meName").addEventListener("click",function(){var n=prompt(t("rename"),myName);if(n&&n.trim()){myName=n.trim();store("jr_name",myName);send({t:"name",name:myName});}});
$("againBtn").addEventListener("click",function(){againSent=true;send({t:"again"});render();});
document.addEventListener("gesturestart",function(e){e.preventDefault();});
setInterval(function(){send({t:"ka"});},4000);
texts();render();connect();
</script>
</body>
</html>
"""
