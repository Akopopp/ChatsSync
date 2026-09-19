/* =====================================================================
   ChatsSync — zubanein
   =====================================================================
   PEHLE yahan 56 zubanein static import hoti thin (ar, bg, ca, cs, da,
   de, el, es, et, fa, fi, fr, he, hi, hu, id, it, ja, ko, ml, lv, nl,
   no, pl, pt, pt_BR, ro, ru, sk, sr, sv, ta, th, tr, uk, vi, zh_CN,
   zh_TW, is, lt ... waghera).

   Static import ka matlab hai ke SAB ki SAB bundle mein chali jaati
   hain, chahe koi istemal kare ya na kare. Nateeja: 13 MB ka ek chunk
   (DashboardIcon-*.js) jo har page par utarta tha — web par bhi aur
   app par bhi.

   Ab sirf woh zubanein jo hamare clients waqai istemal karte hain.
   Kisi aur zuban ki zaroorat paRe to bas uski do line yahan joR dena:
       import de from './locale/de';
       ... aur neeche export mein   de,
   Locale ki files repo mein jyon ki tyon maujood hain, kuch delete
   nahi hua.

   Koi icon, button ya feature is se nahi toot-ta — sirf hataai gayi
   zuban ke bajaye English nazar aayegi.
   ===================================================================== */
import en from './locale/en';
import ur from './locale/ur';
import ar from './locale/ar';

export default {
  en,
  ur,
  ar,
};
