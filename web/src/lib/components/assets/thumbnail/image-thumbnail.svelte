<script context="module">
  const cache = {};
</script>

<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { fade } from 'svelte/transition';
  import { thumbHashToDataURL } from 'thumbhash';
  // eslint-disable-next-line unicorn/prefer-node-protocol
  import { Buffer } from 'buffer';
  import { mdiEyeOffOutline } from '@mdi/js';
  import Icon from '$lib/components/elements/icon.svelte';

  export let url: string;
  export let altText: string | undefined;
  export let title: string | null = null;
  export let heightStyle: string | undefined = undefined;
  export let widthStyle: string;
  export let thumbhash: string | null = null;
  export let curve = false;
  export let shadow = false;
  export let circle = false;
  export let hidden = false;
  export let border = false;
  export let preload = true;
  export let eyeColor: 'black' | 'white' = 'white';
  export let extra = undefined;

  let duration: number = 300;

  let complete = false;
  let img: HTMLImageElement;

  $: {
    if (url) {
      if (cache[url]) {
        // console.log('FOUND');
      }
      cache[url] = thumbhash;
    }
  }
  onMount(async () => {
    try {
      const time = Date.now();
      await img.decode();
      const time2 = Date.now();
      // console.log('ms', time2 - time);
      if (time2 - time < 50) {
        duration = 0;
      }
      complete = true;
    } catch {}
  });
</script>

<img
  bind:this={img}
  loading={preload ? 'eager' : 'lazy'}
  style:width={widthStyle}
  style:height={heightStyle}
  style:filter={hidden ? 'grayscale(50%)' : 'none'}
  style:opacity={hidden ? '0.5' : '1'}
  src={url}
  alt={altText}
  {title}
  class="object-cover transition duration-300 {border
    ? 'border-[3px] border-immich-dark-primary/80 hover:border-immich-primary'
    : ''}"
  class:rounded-xl={curve}
  class:shadow-lg={shadow}
  class:rounded-full={circle}
  class:aspect-square={circle || !heightStyle}
  class:opacity-0={!thumbhash && !complete}
  draggable="false"
/>

{#if hidden}
  <div class="absolute left-1/2 top-1/2 translate-x-[-50%] translate-y-[-50%] transform">
    <Icon {title} path={mdiEyeOffOutline} size="2em" class="text-{eyeColor}" />
  </div>
{/if}

{#if thumbhash && !complete}
  <img
    style:width={widthStyle}
    style:height={heightStyle}
    src={thumbHashToDataURL(Buffer.from(thumbhash, 'base64'))}
    alt={altText}
    {title}
    class="absolute top-0 object-cover"
    class:rounded-xl={curve}
    class:shadow-lg={shadow}
    class:rounded-full={circle}
    draggable="false"
    out:fade={{ duration }}
  />
{/if}

<div class="absolute top-0 text-white">
  {extra?.id}
</div>
