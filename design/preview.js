(() => {
  const $ = id => document.getElementById(id);
  let bindings = [{id:1,app:'微信',key:'W',hide:true}];
  let nextId=2, editing=null, paused=false, hasPermission=true;
  const dialog=$('binding-dialog');
  const feedback=text=>$('feedback').textContent=text;
  const escape=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const chatIcon='<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M4 14c0-5 5-9 11-9s11 4 11 9-5 9-11 9c-2 0-4 0-5-1l-5 3 1-6c-1-1-2-3-2-5Z" fill="currentColor"/><circle cx="11" cy="13" r="1.4" fill="var(--surface)"/><circle cx="19" cy="13" r="1.4" fill="var(--surface)"/></svg>';
  function render(){
    $('count').textContent=bindings.length;
    document.querySelector('.letter-key').textContent=bindings[0]?.key||'W';
    document.querySelector('.key-combination').setAttribute('aria-label','Space 加 '+(bindings[0]?.key||'W'));
    $('empty').hidden=bindings.length>0;
    document.querySelector('.column-labels').hidden=!bindings.length;
    $('binding-list').innerHTML=bindings.map(b=>`<div class="binding-row"><div class="app-identity"><span class="app-icon ${b.app==='微信'?'':'generic'}" aria-hidden="true">${b.app==='微信'?chatIcon:escape(b.app.slice(0,1))}</span><strong>${escape(b.app)}</strong></div><div class="binding-keys" aria-label="Space 加 ${escape(b.key)}"><kbd>space</kbd><span>+</span><kbd>${escape(b.key)}</kbd></div><div class="binding-actions"><button class="switch" role="switch" aria-label="${escape(b.app)}切换桌面后自动隐藏" aria-checked="${b.hide}" data-toggle="${b.id}"></button><details class="row-menu"><summary aria-label="${escape(b.app)}更多操作">⋯</summary><div><button data-edit="${b.id}">编辑快捷键</button><button class="remove" data-remove="${b.id}">移除绑定</button></div></details></div></div>`).join('');
    const w=bindings.find(b=>b.app==='微信');
    $('desktop-toggle').setAttribute('aria-checked',String(Boolean(w?.hide)));
    $('desktop-toggle').disabled=!w;
  }
  function page(name){
    document.querySelectorAll('.page').forEach(el=>el.hidden=el.id!==name);
    document.querySelectorAll('.nav').forEach(el=>{el.classList.toggle('active',el.dataset.page===name);if(el.dataset.page===name)el.setAttribute('aria-current','page');else el.removeAttribute('aria-current');});
  }
  document.querySelectorAll('[data-page]').forEach(el=>el.onclick=()=>page(el.dataset.page));
  document.querySelectorAll('[data-goto]').forEach(el=>el.onclick=()=>page(el.dataset.goto));
  function openBinding(id=null){
    editing=id;const b=bindings.find(x=>x.id===id);
    $('dialog-title').textContent=b?'编辑快捷键':'添加应用';
    $('app').value=b?.app||'Safari';$('key').value=b?.key||'';$('auto-hide').checked=b?.hide??true;
    $('key-error').hidden=true;$('key').removeAttribute('aria-invalid');dialog.showModal();$('key').focus();
  }
  $('add').onclick=()=>openBinding();$('empty-add').onclick=()=>openBinding();
  $('cancel').onclick=$('cancel-x').onclick=()=>dialog.close();
  $('key').addEventListener('input',()=>{$('key').value=$('key').value.toUpperCase();$('key-error').hidden=true;$('key').removeAttribute('aria-invalid');});
  $('binding-form').onsubmit=e=>{
    e.preventDefault();const key=$('key').value.trim().toUpperCase(),app=$('app').value;
    const conflict=bindings.find(b=>b.id!==editing&&(b.key===key||b.app===app));
    if(conflict){$('key-error').textContent=conflict.key===key?`${key} 已分配给${conflict.app}，请换一个键。`:`${app}已有绑定，请编辑现有快捷键。`;$('key-error').hidden=false;$('key').setAttribute('aria-invalid','true');$('key').focus();return;}
    const value={id:editing??nextId++,app,key,hide:$('auto-hide').checked};
    bindings=editing?bindings.map(b=>b.id===editing?value:b):[...bindings,value];render();dialog.close();feedback(`已保存${app}的预览快捷键`);
  };
  $('binding-list').onclick=e=>{
    const button=e.target.closest('button');if(!button)return;
    if(button.dataset.edit)openBinding(Number(button.dataset.edit));
    if(button.dataset.toggle){const b=bindings.find(b=>b.id===Number(button.dataset.toggle));b.hide=!b.hide;button.setAttribute('aria-checked',String(b.hide));$('desktop-toggle').setAttribute('aria-checked',String(Boolean(bindings.find(b=>b.app==='微信')?.hide)));feedback(`${b.app}自动隐藏${b.hide?'已开启':'已关闭'}（预览）`);}
    if(button.dataset.remove){bindings=bindings.filter(b=>b.id!==Number(button.dataset.remove));render();$('add').focus();feedback('已移除预览绑定');}
  };
  $('desktop-toggle').onclick=()=>{const b=bindings.find(b=>b.app==='微信');if(b){b.hide=!b.hide;render();feedback(`微信自动隐藏${b.hide?'已开启':'已关闭'}（预览）`);}};
  function renderStatus(){const label=!hasPermission?'需要授权':paused?'已暂停':'已启用';$('status').innerHTML='<i></i>'+label;$('status').classList.toggle('paused',paused||!hasPermission);$('pause').textContent=$('menu-pause').textContent=paused?'恢复快捷键':'暂停快捷键';$('pause').disabled=$('menu-pause').disabled=!hasPermission;$('menu-status').textContent=!hasPermission?'需要辅助功能权限':paused?'快捷键已暂停':'快捷键已启用';}
  function togglePause(){paused=!paused;renderStatus();feedback(paused?'预览已暂停；真实键盘不受影响':'预览已恢复');}
  $('pause').onclick=$('menu-pause').onclick=togglePause;
  function menu(open){$('menu-panel').hidden=!open;$('show-menu').setAttribute('aria-expanded',String(open));if(open)$('close-menu').focus();else $('show-menu').focus();}
  $('show-menu').onclick=()=>menu($('menu-panel').hidden);$('close-menu').onclick=()=>menu(false);
  $('menu-settings').onclick=()=>{menu(false);page('bindings');document.querySelector('.nav').focus();};
  document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!$('menu-panel').hidden){menu(false);}});
  $('delay').oninput=()=>{$('delay-value').value=`${$('delay').value} ms`;feedback('等待时间仅用于界面演示');};
  $('permission-demo').onclick=()=>{const granted=$('permission-demo').dataset.granted!=='true';$('permission-demo').dataset.granted=String(granted);hasPermission=granted;renderStatus();$('permission-text').textContent=granted?'预览状态：已授权':'预览状态：尚未授权';$('permission-demo').textContent=granted?'模拟未授权':'模拟已授权';feedback('仅改变权限示例，不代表系统授权状态');};
  function swatches(){const cs=getComputedStyle(document.documentElement);$('swatches').innerHTML=[['canvas','雾灰 / 背景'],['surface','内容表面'],['textPrimary','正文'],['textSecondary','辅助文字'],['accent','蓝色 / 操作'],['spark','暖色 / 提示']].map(([key,label])=>`<div class="swatch"><div class="swatch-color" style="background:var(--${key})"></div><p>${label}</p><span>${cs.getPropertyValue('--'+key).trim().toUpperCase()}</span></div>`).join('');}
  $('reduce-transparency').onchange=()=>{document.documentElement.classList.toggle('reduce-transparency',$('reduce-transparency').checked);};
  $('theme').onchange=()=>{document.documentElement.dataset.theme=$('theme').value;swatches();};
  render();swatches();
})();
