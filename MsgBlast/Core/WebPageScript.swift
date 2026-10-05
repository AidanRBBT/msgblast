import Foundation

// Each adapter operates on the rendered page, using normal input events and one Send click.
// Unknown layouts stay usable as embedded pages but cannot receive shared submissions.
struct WebPageScript {
    let provider: WebProvider
    private var helpers: String {
        let selectors: (editor: String, send: String, messages: String, account: String)
        switch provider {
        case .muse: return MusePageScript.helpers
        case .chatgpt:
            selectors = (#"textarea[aria-label="Chat with ChatGPT"],#prompt-textarea[contenteditable="true"]"#,
                         #"button[data-testid="send-button"],button[aria-label="Send message"],button[aria-label="Send prompt"]"#,
                         #"[data-message-author-role][data-message-id]"#,
                         #"button[data-testid="accounts-profile-button"],button[aria-label="Open profile menu"]"#)
        case .claude:
            selectors = (#"[contenteditable="true"][data-testid="chat-input"],div[contenteditable="true"].ProseMirror"#,
                         #"button[aria-label="Send message"],button[data-testid="send-button"]"#,
                         #"[data-testid="user-message"],[data-testid="assistant-message"],.font-claude-message"#,
                         #"button[data-testid="user-menu-button"],button[aria-label="User menu"],button[aria-label="Open user menu"]"#)
        case .grok:
            selectors = (#"textarea[aria-label="Ask Grok anything"],textarea[placeholder="What do you want to know?"]"#,
                         #"button[data-testid="chat-submit"],button[aria-label="Submit"]"#,
                         #"[data-message-id][data-message-role],.message-bubble"#,
                         #"button[data-testid="user-menu-button"],button[aria-label="User menu"],button[aria-label="Open user menu"],button[aria-label="Account menu"]"#)
        }
        let config: [String: String] = ["name":provider.name,"provider":provider.rawValue,"host":provider.homeURL.host!,"editor":selectors.editor,"send":selectors.send,"messages":selectors.messages,"account":selectors.account]
        let json = String(data: try! JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]), encoding: .utf8)!
        return "const config = \(json);\n" + #"""
        const visible = e => !!e && e.getClientRects().length > 0 && getComputedStyle(e).visibility !== 'hidden';
        const all = selector => [...document.querySelectorAll(selector)].filter(visible);
        const unique = selector => { const es=all(selector); return es.length===1 ? es[0] : null; };
        const editor = () => unique(config.editor);
        const draft = input => input ? (input instanceof HTMLTextAreaElement ? input.value : input.innerText).replace(/\r\n/g,'\n') : '';
        const normalized = s => s.replace(/\s+/g,' ').trim();
        // Kept in WebKit's isolated world, never in page storage. Node identities survive
        // visibility and history-order changes; replacing old nodes invalidates continuity.
        const observation = globalThis.__msgblastObservation ??= {ids:new WeakMap(),nextID:0,interrupted:false};
        if (!observation.listening) {
            observation.listening=true;
            for (const event of ['pointerdown','keydown','input','popstate'])
                window.addEventListener(event,e=>{if(e.isTrusted) observation.interrupted=true;},true);
        }
        const pathAllowed = () => location.protocol==='https:' && location.hostname===config.host &&
            (config.provider==='claude' ? /^\/(new|chat\/[a-zA-Z0-9-]+)\/?$/.test(location.pathname) : /^(\/|\/c\/[a-zA-Z0-9-]+\/?)$/.test(location.pathname));
        const messages = () => [...document.querySelectorAll(config.messages)].filter(e => !e.parentElement?.closest(config.messages)).map(e => {
            let role=e.getAttribute('data-message-author-role') || e.getAttribute('data-message-role');
            if (!role && config.provider==='claude') role=e.getAttribute('data-testid')==='user-message' ? 'user' : 'assistant';
            if (!role && config.provider==='grok') role=e.classList.contains('items-end') || e.closest('[data-role="user"],.items-end') ? 'user' : 'assistant';
            const copy=e.cloneNode(true); copy.querySelectorAll('button,[role="button"],time').forEach(n=>n.remove());
            copy.querySelectorAll('br,p,div,li,pre,blockquote').forEach(n=>n.append(document.createTextNode(' ')));
            if (!observation.ids.has(e)) observation.ids.set(e,`node-${++observation.nextID}`);
            return {id:e.getAttribute('data-message-id') || e.closest('[data-message-id]')?.getAttribute('data-message-id') || observation.ids.get(e),role:role||'unknown',text:normalized(copy.textContent||'')};
        });
        const status = () => {
            const input=editor(); let reason='';
            const login=all('button,a').some(e=>/^(log in|sign in|sign up|sign up for free)$/i.test(normalized(e.innerText||e.getAttribute('aria-label')||'')));
            const modal=all('[role="dialog"],[aria-modal="true"]').length>0;
            const generating=all('button[data-testid="stop-button"],button[aria-label="Stop generating"],button[aria-label="Stop response"],button[aria-label="Stop"] ').length>0;
            if (!pathAllowed()) reason=`Open a ${config.name} chat to send from MsgBlast.`;
            else if (login || !all(config.account).length) reason=`Sign in to ${config.name} and open a chat. If already signed in, use the page while its layout is unsupported.`;
            else if (modal) reason=`Finish the open dialog in ${config.name} first.`;
            else if (generating) reason=`Wait for ${config.name} to finish its current reply.`;
            else if (!input || input.disabled || input.readOnly || input.getAttribute('aria-disabled')==='true') reason=`Waiting for ${config.name}’s message field.`;
            return {url:location.href,ready:!reason,reason:reason||`${config.name} chat ready`,draft:draft(input)};
        };
        const inspect = () => ({...status(),messages:pathAllowed()?messages():[],submissionInterrupted:observation.interrupted});
        """#
    }
    var inspect: String { provider == .muse ? MusePageScript.inspect : helpers + "\nreturn inspect();" }
    var prepare: String {
        if provider == .muse { return MusePageScript.prepare }
        return helpers + #"""
        const before=status();
        if (!before.ready) return {ok:false,reason:before.reason};
        if (before.draft.trim()) return {ok:false,reason:`${config.name} already has a draft. Send or clear it in the page first.`};
        const baseline=messages(),input=editor();
        const existingConversationPaths=[...document.querySelectorAll('a[href]')].map(a=>new URL(a.href,location.href)).filter(u=>u.origin===location.origin).map(u=>u.pathname);
        if (input instanceof HTMLTextAreaElement) {
            Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set.call(input,text);
            input.dispatchEvent(new Event('input',{bubbles:true}));
            input.dispatchEvent(new Event('change',{bubbles:true}));
        } else {
            // Let contenteditable/ProseMirror process a browser editing operation.
            input.focus();
            if (!document.execCommand('insertText',false,text)) return {ok:false,reason:'The page did not accept text. Use its composer directly.'};
        }
        return {ok:true,messageIDs:baseline.map(m=>m.id),messages:baseline,existingConversationPaths};
        """#
    }
    var clickSend: String {
        if provider == .muse { return MusePageScript.clickSend }
        return helpers + #"""
        const current=status();
        if (!current.ready || current.url!==expectedURL || current.draft!==text)
            return {clicked:false,reason:`${config.name} changed during preparation. Review its draft; nothing was clicked.`};
        const send=unique(config.send);
        if (!send || send.disabled || send.getAttribute('aria-disabled')==='true')
            return {clicked:false,reason:`${config.name}’s Send control is unavailable. Review the prepared draft.`};
        observation.interrupted=false;
        send.click(); return {clicked:true};
        """#
    }

    var fixture: String {
        if provider == .muse { return MusePageScript.fixture }
        let input = provider == .claude ? #"<div class="ProseMirror" role="textbox" aria-label="Message Claude" contenteditable="true"></div>"# : "<textarea aria-label=\"\(provider == .chatgpt ? "Chat with ChatGPT" : "Ask Grok anything")\"></textarea>"
        let send = provider == .grok ? #"data-testid="chat-submit" aria-label="Submit""# : #"aria-label="Send message""#
        let account = provider == .chatgpt ? #"data-testid="accounts-profile-button""# : #"data-testid="user-menu-button""#
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>
        :root{color-scheme:light dark;font:15px -apple-system,sans-serif}body{margin:0;padding:22px;background:Canvas;color:CanvasText}header{display:flex;gap:12px;align-items:center;border-bottom:1px solid #8884;padding-bottom:16px}small{color:#888}#transcript{min-height:150px;padding:20px 0}article{background:#8882;border-radius:16px;margin:12px 0;padding:14px}textarea,[contenteditable]{box-sizing:border-box;width:100%;min-height:70px;padding:12px;font:inherit;border:1px solid #8885;border-radius:14px}button{font:inherit;margin:8px 0;padding:8px 14px;border-radius:10px;border:1px solid #8885}[hidden]{display:none!important}
        </style></head><body><header><strong>\(provider.name)</strong><small>Local fixture · no real sends</small></header>
        <div id="login" hidden><p>Sign in to continue.</p><button onclick="chat.hidden=false;login.hidden=true">Sign in to fixture</button></div>
        <main id="chat"><button \(account)>Fixture account</button><div id="transcript"></div>\(input)<button \(send) disabled>Send</button><button onclick="chat.hidden=true;login.hidden=false">Sign out of fixture</button></main>
        <script>
        const provider='\(provider.rawValue)',input=document.querySelector('textarea,[contenteditable]'),send=document.querySelector('button[aria-label]');
        const value=()=>input.tagName==='TEXTAREA'?input.value:input.innerText;
        input.addEventListener('input',()=>send.disabled=!value().trim());
        send.addEventListener('click',()=>{const text=value();if(!text.trim())return;
        function add(role,text){const a=document.createElement('article');
        if(provider==='chatgpt'){a.dataset.messageAuthorRole=role;a.dataset.messageId=crypto.randomUUID();}
        if(provider==='claude'){a.dataset.testid=role==='user'?'user-message':'assistant-message';}
        if(provider==='grok'){a.dataset.messageRole=role;a.dataset.messageId=crypto.randomUUID();a.className='message-bubble';}
        a.textContent=text;document.getElementById('transcript').append(a);a.scrollIntoView({block:'nearest'});}
        add('user',text);if(input.tagName==='TEXTAREA')input.value='';else input.textContent='';send.disabled=true;
        history.replaceState(null,'',provider==='claude'?'/chat/fixture-conversation':'/c/fixture-conversation');
        setTimeout(()=>add('assistant','\(provider.name) fixture reply: '+text),350);});
        </script></body></html>
        """
    }
}
