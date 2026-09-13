<template>
  <!--
    PEHLE: <div class="overflow-auto bg-n-surface-1 w-full px-6">
             <div class="max-w-5xl mx-auto pb-12">

    Do masle the:
      1. max-w-5xl (1024px) content ko qaid kar deta tha — baRi screen par
         dono taraf khali jagah, aur andar sab kuch simat kar chhota.
      2. px-6 (24px) mobile par bohat zyada tha, aur min-w-0 na hone ki
         wajah se andar ke grid/table sikuR jaate the bajaye scroll hone ke.

    AB: Settings wale pages (Agents, Labels) jaisa —
        flex flex-col w-full h-full min-w-0, aur padding screen ke hisaab se.
        Isi liye wahan layout kharab nahi hota: cheezein apni asli chauRai
        rakhti hain aur frame ke andar right-scroll hoti hain.
  -->
  <div
    class="flex flex-col w-full h-full min-w-0 overflow-auto bg-n-surface-1 px-3 sm:px-6 font-inter"
  >
    <div class="w-full min-w-0 max-w-[1280px] mx-auto pb-12">
      <router-view />
    </div>
  </div>
</template>
