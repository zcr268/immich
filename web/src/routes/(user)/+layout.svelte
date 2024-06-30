<script lang="ts">
  import UploadCover from '$lib/components/shared-components/drag-and-drop-upload-overlay.svelte';
  import { page } from '$app/stores';
  import { assetViewingStore } from '$lib/stores/asset-viewing.store';
  import { handlePromiseError } from '$lib/utils';
  let { isViewing: showAssetViewer, setAsset, setGridScrollTarget } = assetViewingStore;

  // This block takes care of opening the viewer.
  // $page.data.asset is loaded by route specific +page.ts loaders if that
  // route contains the assetId path.
  $: {
    if ($page.data.asset) {
      console.log('layout - showing viewer');
      setAsset($page.data.asset);
    } else {
      console.log('closing viewer');
      $showAssetViewer = false;
    }
    const asset = $page.url.searchParams.get('asset');
    const date = $page.url.searchParams.get('date');
    setGridScrollTarget({ assetId: asset, date });
  }
  // $: {
  //   const asset = $page.url.searchParams.get('asset');
  //   const date = $page.url.searchParams.get('date');
  //   handlePromiseError(setGridScrollTarget({ assetId: asset, date }));
  // }
</script>

<div class:display-none={$showAssetViewer}>
  <slot />
</div>
<UploadCover />

<style>
  .display-none {
    display: none;
  }
</style>
