(async function(){
'use strict';
const cfg=window.NAGI_CONFIG;
const roots=document.querySelectorAll('[data-editorial]');
if(!roots.length)return;
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const safeImg=s=>{try{const u=new URL(s);return u.protocol==='https:'?u.href:''}catch{return ''}};
const stamp=s=>s?new Date(s).toLocaleDateString('ja-JP',{year:'numeric',month:'2-digit',day:'2-digit'}):'';
for(const root of roots){
 const box=root.querySelector('.items');if(!box)continue;
 const kind=root.dataset.editorial,limit=Number(root.dataset.limit||0);
 const article=new URLSearchParams(location.search).get('article');
 if(!cfg?.supabaseUrl||!cfg?.supabasePublishableKey){box.innerHTML='<p class="empty">記事の接続設定を確認してください。</p>';continue}
 try{
 const endpoint=new URL(cfg.supabaseUrl.replace(/\/$/,'')+'/rest/v1/nagi_content_posts');
 endpoint.searchParams.set('select','id,kind,category,title,excerpt,body,cover_url,gallery_urls,published_at');
 endpoint.searchParams.set('kind','eq.'+kind);
 endpoint.searchParams.set('status','in.(published,scheduled)');
 endpoint.searchParams.set('published_at','lte.'+new Date().toISOString());
 if(article)endpoint.searchParams.set('id','eq.'+article);
 else{endpoint.searchParams.set('order','published_at.desc');if(limit)endpoint.searchParams.set('limit',String(limit))}
 const res=await fetch(endpoint,{headers:{apikey:cfg.supabasePublishableKey,Authorization:'Bearer '+cfg.supabasePublishableKey,'Accept':'application/json'}});
 if(!res.ok)throw Error('HTTP '+res.status);
 const data=await res.json();
 if(article){
 if(!data.length){box.innerHTML='<p class="empty">記事が見つかりません。</p>';continue}
 const x=data[0],img=safeImg(x.cover_url);
 const gallery=(x.gallery_urls||[]).map(safeImg).filter(Boolean);
 box.innerHTML='<article><time>'+esc(stamp(x.published_at))+'</time><h2 class="article-title">'+esc(x.title)+'</h2>'+(img?'<img src="'+esc(img)+'" alt="'+esc(x.title)+'" loading="lazy">':'')+'<div class="article-body">'+esc(x.body)+'</div>'+gallery.map(u=>'<img src="'+esc(u)+'" alt="記事の写真" loading="lazy">').join('')+'</article>';
 box.style.display='block';
 }else{
 box.innerHTML=data.length?data.map(x=>{const img=safeImg(x.cover_url);return '<article><a href="'+kind+'.html?article='+encodeURIComponent(x.id)+'">'+(img?'<img src="'+esc(img)+'" alt="" loading="lazy">':'')+'<time>'+esc(stamp(x.published_at))+'</time><h3 class="article-title">'+esc(x.title)+'</h3>'+(x.category?'<small>'+esc(x.category)+'</small>':'')+'<p>'+esc(x.excerpt||'')+'</p></a></article>'}).join(''):'<p class="empty">現在、公開中の記事はありません。</p>';
 }
 }catch(err){console.error('NAGI editorial:',err);box.innerHTML='<p class="empty">記事を読み込めませんでした。時間をおいて再度お試しください。</p>'}
}
})();
