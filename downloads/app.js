(() => {
'use strict';
const conf = window.SITE_CONFIG;
if (!conf || !Array.isArray(conf.servers) || !conf.servers.length) {
  console.error('网站配置不存在或区服列表为空，请检查 config.js。'); return;
}
const byId = id => document.getElementById(id);
const make = (name, className, txt) => {
  const e=document.createElement(name); if(className)e.className=className;
  if(txt!==undefined)e.textContent=txt; return e;
};
const cultivation = {0:'筑基',1:'灵虚',2:'和合',3:'元婴',4:'空冥',5:'履霜',6:'渡劫',7:'寂灭',8:'大乘',20:'上仙',21:'真仙',22:'天仙',30:'狂魔',31:'魔圣',32:'魔尊'};
const servers = conf.servers;
let current = servers.find(s => s.id === conf.initialServer) || servers[0];
let controller=null;
function setCommonLinks() {
  document.title = (conf.siteName||'2004WM经典服') + '｜' + (conf.slogan||'山海相逢，故梦长开');
  document.querySelectorAll('.js-register-link').forEach(a=>a.href=conf.registerUrl);
  document.querySelectorAll('.js-download-link, .fixed-download-link').forEach(a=>a.href=conf.downloadUrl);
  document.querySelectorAll('.js-qq').forEach(e=>e.textContent=conf.qqNumber||'929090661');
  ['qqNews','qqService'].forEach(id => {if (byId(id)) byId(id).href=conf.qqUrl;});
}
function buildZones() {
  const grid=byId('zoneCards'); const tabs=byId('rankTabs');
  grid.replaceChildren();tabs.replaceChildren();
  servers.forEach((s,i)=>{
    const card=make('button','zone-card'); card.type='button';card.dataset.zone=s.id;
    const img=make('img');img.src=s.cover||'./assets/world.webp';img.alt='';img.loading='lazy';
    const overlay=make('span','zone-overlay');
    const tag=make('span','zone-tag',s.tag || s.code || ('区服 '+(i+1)));
    const info=make('span','zone-card-bottom');
    const label=make('span','zone-title',s.name);const motto=make('span','zone-slogan',s.slogan||'');
    const arrow=make('span','zone-arrow','↗');
    info.append(label,motto);card.append(img,overlay,tag,info,arrow);
    card.addEventListener('click',()=>{selectZone(s.id);byId('ranks').scrollIntoView({behavior:'smooth',block:'start'});});
    grid.append(card);
    const tab=make('button','rank-tab',s.code||s.name); tab.type='button'; tab.dataset.zone=s.id;
    tab.addEventListener('click',()=>selectZone(s.id));tabs.append(tab);
  });
}
function showBlank(title,desc){
  const body=byId('rankRows');body.replaceChildren();
  const tr=make('tr');const td=make('td','rank-empty');td.colSpan=4;
  td.append(make('strong','',title),make('span','',desc));tr.append(td);body.append(tr);
}
function renderRanks(items){
  const body=byId('rankRows');body.replaceChildren();
  items.slice(0,10).forEach((x,i)=>{
    const tr=make('tr');const rawRank=Number(x.rank);
    const rank=Number.isFinite(rawRank)&&rawRank>0?rawRank:i+1;
    tr.append(make('td',rank<=3?'top-place':'',String(rank)));
    tr.append(make('td','player-name',String(x.name??'未命名角色')));
    const lv=Number(x.level);tr.append(make('td','',Number.isFinite(lv)?String(lv):'—'));
    const cult=x.cultivation;tr.append(make('td','',cult==null?'—':(cultivation[cult]||('修真 '+String(cult)))));
    body.append(tr);
  });
}
async function refreshRanks(){
  if(controller)controller.abort();controller=null;
  const zone=current;
  const more=byId('rankMore');more.hidden=!zone.rankPage;
  if(zone.rankPage)more.href=zone.rankPage;
  byId('rankSubtitle').textContent=`${zone.code} · ${zone.name}`;
  byId('rankRefresh').textContent='';
  if(!zone.rankApi){
    showBlank('独立排行榜待接入','该区尚未提供排行榜接口，当前不会展示其他区服的数据。');
    byId('rankStatus').textContent='等后台接口配置完成后将自动显示。';return;
  }
  showBlank('正在读取排行榜','读取 '+zone.name+' 的独立等级数据…');
  byId('rankStatus').textContent='读取中';
  const ctrl=new AbortController();controller=ctrl;
  try {
    const url=zone.rankApi+(zone.rankApi.includes('?')?'&':'?')+'_='+Date.now();
    const resp=await fetch(url,{signal:ctrl.signal,cache:'no-store'});
    if(!resp.ok) throw new Error('HTTP '+resp.status);
    const data=await resp.json();
    if(current.id!==zone.id)return;
    if(!data || data.ok!==true || !Array.isArray(data.items))throw new Error('数据格式不正确');
    if(!data.items.length)showBlank('当前暂无上榜角色','该区榜单暂无可显示数据。');
    else renderRanks(data.items);
    if(data.updatedAt){const d=new Date(data.updatedAt);if(!Number.isNaN(+d))byId('rankRefresh').textContent='更新于 '+d.toLocaleString('zh-CN',{hour12:false});}
    byId('rankStatus').textContent='每60秒自动更新 · 前10名';
  } catch(err){
    if(err.name==='AbortError')return;
    if(current.id===zone.id){showBlank('排行榜暂时不可用','请检查本区接口是否正常，或稍后重试。');byId('rankStatus').textContent='无法读取本区独立排行榜';}
  } finally{if(controller===ctrl)controller=null;}
}
function selectZone(id){
  const found=servers.find(s=>s.id===id); if(!found)return;
  current=found;
  document.querySelectorAll('[data-zone]').forEach(b=>{const active=b.dataset.zone===id;b.classList.toggle('selected',active);b.setAttribute('aria-pressed',active?'true':'false');});
  refreshRanks();
}
function initMobile(){
  const btn=byId('mobileMenu'),nav=byId('mainNav');
  btn.addEventListener('click',()=>{const open=nav.classList.toggle('nav-open');btn.setAttribute('aria-expanded',open?'true':'false');});
  nav.querySelectorAll('a').forEach(a=>a.addEventListener('click',()=>{nav.classList.remove('nav-open');btn.setAttribute('aria-expanded','false');}));
}
function initGallery(){
  const modal=byId('imageModal');const img=byId('modalImage');
  function close(){modal.hidden=true;img.removeAttribute('src');document.body.classList.remove('modal-open');}
  document.querySelectorAll('.view-image').forEach(b=>b.addEventListener('click',()=>{
    img.src=b.dataset.image;img.alt=b.dataset.caption||'游戏截图';byId('modalCaption').textContent=b.dataset.caption||'';
    modal.hidden=false;document.body.classList.add('modal-open');byId('closeImage').focus();
  }));
  byId('closeImage').addEventListener('click',close);
  modal.addEventListener('click',e=>{if(e.target===modal)close();});
  document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!modal.hidden)close();});
}
setCommonLinks();buildZones();initMobile();initGallery();selectZone(current.id);
setInterval(()=>{if(!document.hidden)refreshRanks();},60000);
})();
