import Foundation

// DOM contract observed in Muse's shipped frontend. No private RPCs or session tokens.
enum MusePageScript {
    static let helpers = #"""
    const visible = e => !!e && e.getClientRects().length > 0 && getComputedStyle(e).visibility !== 'hidden';
    const unique = selector => { const es = [...document.querySelectorAll(selector)].filter(visible); return es.length === 1 ? es[0] : null; };
    const editor = () => unique('textarea[aria-label="Message"]');
    const buttons = label => [...document.querySelectorAll('button')].filter(e => visible(e) && e.getAttribute('aria-label') === label);
    const normalized = s => s.replace(/\s+/g, ' ').trim();
    const messages = () => [...document.querySelectorAll('[data-message-item][data-message-id][data-message-role]')].map(e => {
        const copy = e.cloneNode(true);
        copy.querySelectorAll('button,[role="button"],time').forEach(n => n.remove());
        return {id:e.getAttribute('data-message-id'),role:e.getAttribute('data-message-role'),text:normalized(copy.textContent || '').replace(/^You:\s*/, '')};
    });
    const status = () => {
        let reason = '';
        const input = editor();
        const allowed = location.protocol === 'https:' && location.hostname === 'muse.ai' && location.pathname === '/';
        if (!allowed) reason = 'Open the main Muse chat to send from MsgBlast.';
        else if (buttons('Back to main chat').length) reason = 'Return to the main Muse chat before sending.';
        else if (!document.querySelector('[aria-label="Chat messages"],#hatch-chat-scroll')) reason = 'Sign in to Muse and open your main chat.';
        else if (!input) reason = 'Waiting for Muse’s message field. If this persists, use the embedded page directly.';
        else if (input.disabled || input.readOnly) reason = 'Muse needs attention before it can accept a message.';
        return {url:location.href,ready:reason === '',reason:reason || 'Main Muse chat ready',draft:input?.value || ''};
    };
    const inspect = () => ({...status(),messages:location.protocol === 'https:' && location.hostname === 'muse.ai' && location.pathname === '/' ? messages() : []});
    """#

    static let inspect = helpers + "\nreturn inspect();"
    static let prepare = helpers + #"""
    const before = status();
    if (!before.ready) return {ok:false,reason:before.reason};
    if (before.draft.trim()) return {ok:false,reason:'Muse already has a draft. Send or clear it in the page first.'};
    const input = editor();
    Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(input, text);
    input.dispatchEvent(new Event('input', {bubbles:true}));
    input.dispatchEvent(new Event('change', {bubbles:true}));
    return {ok:true,messageIDs:[...document.querySelectorAll('[data-message-item][data-message-id][data-message-role]')].map(e => e.getAttribute('data-message-id'))};
    """#
    static let clickSend = helpers + #"""
    const current = status();
    if (!current.ready || current.url !== expectedURL || current.draft !== text)
        return {clicked:false,reason:'Muse changed during preparation. Nothing was clicked; review its draft.'};
    const send = buttons('Send');
    if (send.length !== 1 || send[0].disabled || send[0].getAttribute('aria-disabled') === 'true')
        return {clicked:false,reason:'Muse’s Send control is unavailable. Review the prepared draft in Muse.'};
    send[0].click();
    return {clicked:true};
    """#

    // This local HTML exercises the same WKWebView and DOM adapter as live mode.
    // It is only loaded for the app's existing demo environment; it makes no network requests.
    static let fixture = #"""
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>
    :root { color-scheme:light dark; font:15px -apple-system,sans-serif; } body{margin:0;padding:24px; background:Canvas;color:CanvasText}
    header{display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #8884;padding-bottom:16px}
    small{color:#888} #hatch-chat-scroll{min-height:180px;padding:24px 0} article{padding:14px 16px;margin:12px 0;background:#8882;border-radius:16px}
    [data-message-role=user]{background:#1684ff;color:white;margin-left:45px} textarea{box-sizing:border-box;width:100%;min-height:65px;font:inherit;padding:12px;border:1px solid #8885;border-radius:14px}
    button{font:inherit;padding:8px 14px;margin:8px 0;border-radius:10px;border:1px solid #8885;cursor:pointer} [hidden]{display:none!important}
    </style></head><body><header><strong>Muse</strong><small>Local fixture · no real sends</small></header>
    <div id="login" hidden><p>Sign in to continue.</p><button onclick="login.hidden=true;chat.hidden=false">Sign in to fixture</button></div>
    <div id="chat"><div id="hatch-chat-scroll" aria-label="Chat messages"><article data-message-item data-message-id="welcome" data-message-role="assistant">Ready to compare an idea? Send a message from MsgBlast’s shared composer.</article></div>
    <textarea aria-label="Message" placeholder="Message"></textarea><button aria-label="Send" disabled>Send</button>
    <button onclick="chat.hidden=true;login.hidden=false">Sign out of fixture</button></div>
    <script>
    const input=document.querySelector('textarea'),send=document.querySelector('[aria-label=Send]');
    input.addEventListener('input',()=>{send.disabled=!input.value.trim()});
    send.addEventListener('click',()=>{
      const text=input.value;if(!text.trim())return;
      function add(role,text){const a=document.createElement('article');a.dataset.messageItem='true';a.dataset.messageId=crypto.randomUUID();a.dataset.messageRole=role;a.textContent=text;document.getElementById('hatch-chat-scroll').append(a);a.scrollIntoView({block:'nearest'});}
      add('user',text);input.value='';send.disabled=true;
      setTimeout(()=>add('assistant','Fixture reply: '+text),350);
    });
    </script></body></html>
    """#
}
