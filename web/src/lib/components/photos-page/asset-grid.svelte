<script lang="ts">
  import { afterNavigate, beforeNavigate, goto } from '$app/navigation';
  import { AppRoute, AssetAction } from '$lib/constants';
  import type { AssetInteractionStore } from '$lib/stores/asset-interaction.store';
  import { assetViewingStore } from '$lib/stores/asset-viewing.store';
  import {
    AssetBucket,
    BucketPosition,
    isSelectingAllAssets,
    type AssetStore,
    type Viewport,
  } from '$lib/stores/assets.store';
  import { locale, showDeleteModal } from '$lib/stores/preferences.store';
  import { isSearchEnabled } from '$lib/stores/search.store';
  import { featureFlags } from '$lib/stores/server-config.store';
  import { deleteAssets } from '$lib/utils/actions';
  import { type ShortcutOptions, shortcuts } from '$lib/actions/shortcut';
  import { formatGroupTitle, splitBucketIntoDateGroups } from '$lib/utils/timeline-util';
  import type { AlbumResponseDto, AssetResponseDto } from '@immich/sdk';
  import { DateTime } from 'luxon';
  import { createEventDispatcher, onDestroy, onMount } from 'svelte';
  import IntersectionObserver from '../asset-viewer/intersection-observer.svelte';
  import Portal from '../shared-components/portal/portal.svelte';
  import Scrollbar from '../shared-components/scrollbar/scrollbar.svelte';
  import ShowShortcuts from '../shared-components/show-shortcuts.svelte';
  import AssetDateGroup from './asset-date-group.svelte';
  import { archiveAssets, stackAssets } from '$lib/utils/asset-utils';
  import DeleteAssetDialog from './delete-asset-dialog.svelte';
  import { handlePromiseError } from '$lib/utils';
  import { selectAllAssets } from '$lib/utils/asset-utils';
  import { navigate } from '$lib/utils/navigation';

  export let isSelectionMode = false;
  export let singleSelect = false;
  export let assetStore: AssetStore;
  export let assetInteractionStore: AssetInteractionStore;
  export let removeAction: AssetAction | null = null;
  export let withStacked = false;
  export let showArchiveIcon = false;
  export let isShared = false;
  export let album: AlbumResponseDto | null = null;
  export let isShowDeleteConfirmation = false;

  //TODO - calculate this

  $: isTrashEnabled = $featureFlags.loaded && $featureFlags.trash;

  const { assetSelectionCandidates, assetSelectionStart, selectedGroup, selectedAssets, isMultiSelectState } =
    assetInteractionStore;
  const viewport: Viewport = { width: 0, height: 0 };
  let { isViewing: showAssetViewer, asset: viewingAsset, preloadAssets, gridScrollTarget } = assetViewingStore;

  let element: HTMLElement;
  let timelineElement: HTMLElement;
  let showShortcuts = false;
  let showSkeleton = true;
  let assetGroupCmp: AssetDateGroup[] = [];
  let internalScroll = false;

  $: timelineY = element?.scrollTop || 0;
  $: isEmpty = $assetStore.initialized && $assetStore.buckets.length === 0;
  $: idsSelectedAssets = [...$selectedAssets].map(({ id }) => id);
  $: isAllArchived = [...$selectedAssets].every((asset) => asset.isArchived);
  $: {
    if (isEmpty) {
      assetInteractionStore.clearMultiselect();
    }
  }

  $: {
    void assetStore.updateViewport(viewport);
  }

  let navigating = false;
  const dispatch = createEventDispatcher<{ select: AssetResponseDto; escape: void }>();

  const completeNav = () => {
    navigating = false;
    if (internalScroll) {
      internalScroll = false;
      return;
    }
    void $assetStore.scheduleScrollToAssetId($gridScrollTarget);
    $gridScrollTarget?.assetId ? void 0 : (showSkeleton = false);
  };

  afterNavigate(({ complete }) => {
    complete.then(completeNav, completeNav);
  });

  beforeNavigate(() => {
    navigating = true;
  });

  if (import.meta.hot) {
    // hmr will set the skeleton back to true by default, but there is no subsequent history
    // load to complete the load, so the stencil stays during hmr
    /* eslint-disable-next-line  unicorn/no-lonely-if */
    if (import.meta.hot.data.id) {
      showSkeleton = false;
    }
  }

  onMount(async () => {
    if ($assetStore.initialized) {
      showSkeleton = false;
    } else {
      $assetStore.connect();
      await $assetStore.init(viewport);
    }
  });

  onDestroy(() => {
    $assetStore.disconnect();
  });

  /* eslint-disable-next-line  @typescript-eslint/no-explicit-any */
  function wrapRAF<T extends (...args: any) => any>(fn: T) {
    let updating = false;
    /* eslint-disable-next-line  @typescript-eslint/no-explicit-any */
    return (...args: any) => {
      if (updating) {
        return;
      }
      updating = true;
      requestAnimationFrame(() => {
        fn.call(undefined, ...args);
        updating = false;
      });
    };
  }

  const updateScrollPos = ({ detail }: { detail: number }) => {
    element.scrollTop = detail;
  };
  const updateScrollPositon = wrapRAF(updateScrollPos);

  const scrollTimelineY = () => {
    timelineY = element?.scrollTop || 0;
  };

  const handleTimelineScroll = wrapRAF(scrollTimelineY);

  function scrollTimeline(event: CustomEvent) {
    element.scrollBy(0, event.detail.heightDelta);
  }
  const handleScrollTimeline = wrapRAF(scrollTimeline);

  const onAssetInGrid = async (asset: AssetResponseDto) => {
    if (navigating) {
      return;
    }
    $gridScrollTarget = { assetId: asset.id, date: null };

    await navigate(
      { targetRoute: 'current', assetId: null, assetGridScrollTarget: $gridScrollTarget },
      { replaceState: true },
    );
  };

  const scrollToTarget = ({ target, offset }: { target: AssetBucket; offset: number }) => {
    const buckets = $assetStore.buckets;

    // Set 'above' to all bucket positions above the target so that in case they
    // are loaded, the scroll positions are maintained
    for (const bucket of buckets) {
      if (bucket === target) {
        break;
      }
      bucket.position = BucketPosition.Above;
    }
    debugger;
    internalScroll = true;
    element.scrollTo({ top: offset });
    $assetStore.clearPendingScroll();
    showSkeleton = false;
  };

  const trashOrDelete = async (force: boolean = false) => {
    isShowDeleteConfirmation = false;
    await deleteAssets(!(isTrashEnabled && !force), (assetIds) => assetStore.removeAssets(assetIds), idsSelectedAssets);
    assetInteractionStore.clearMultiselect();
  };

  const onDelete = () => {
    const hasTrashedAsset = Array.from($selectedAssets).some((asset) => asset.isTrashed);

    if ($showDeleteModal && (!isTrashEnabled || hasTrashedAsset)) {
      isShowDeleteConfirmation = true;
      return;
    }
    handlePromiseError(trashOrDelete(hasTrashedAsset));
  };

  const onForceDelete = () => {
    if ($showDeleteModal) {
      isShowDeleteConfirmation = true;
      return;
    }
    handlePromiseError(trashOrDelete(true));
  };

  const onStackAssets = async () => {
    const ids = await stackAssets(Array.from($selectedAssets));
    if (ids) {
      assetStore.removeAssets(ids);
      dispatch('escape');
    }
  };

  const toggleArchive = async () => {
    const ids = await archiveAssets(Array.from($selectedAssets), !isAllArchived);
    if (ids) {
      assetStore.removeAssets(ids);
      deselectAllAssets();
    }
  };

  const focusElement = () => {
    if (document.activeElement === document.body) {
      element.focus();
    }
  };

  $: shortcutList = (() => {
    if ($isSearchEnabled || $showAssetViewer) {
      return [];
    }

    const shortcuts: ShortcutOptions[] = [
      { shortcut: { key: 'Escape' }, onShortcut: () => dispatch('escape') },
      { shortcut: { key: '?', shift: true }, onShortcut: () => (showShortcuts = !showShortcuts) },
      { shortcut: { key: '/' }, onShortcut: () => goto(AppRoute.EXPLORE) },
      { shortcut: { key: 'A', ctrl: true }, onShortcut: () => selectAllAssets(assetStore, assetInteractionStore) },
      { shortcut: { key: 'PageDown' }, preventDefault: false, onShortcut: focusElement },
      { shortcut: { key: 'PageUp' }, preventDefault: false, onShortcut: focusElement },
    ];

    if ($isMultiSelectState) {
      shortcuts.push(
        { shortcut: { key: 'Delete' }, onShortcut: onDelete },
        { shortcut: { key: 'Delete', shift: true }, onShortcut: onForceDelete },
        { shortcut: { key: 'D', ctrl: true }, onShortcut: () => deselectAllAssets() },
        { shortcut: { key: 's' }, onShortcut: () => onStackAssets() },
        { shortcut: { key: 'a', shift: true }, onShortcut: toggleArchive },
      );
    }

    return shortcuts;
  })();

  const handleSelectAsset = (asset: AssetResponseDto) => {
    if (!assetStore.albumAssets.has(asset.id)) {
      assetInteractionStore.selectAsset(asset);
    }
  };

  function intersectedHandler(event: CustomEvent) {
    const element_ = event.detail.container as HTMLElement;
    const target = element_.firstChild as HTMLElement;
    if (target) {
      const bucketDate = target.id.split('_')[1];
      void assetStore.loadBucket(bucketDate, event.detail.position);
    }
  }

  const handlePrevious = async () => {
    const previousAsset = await assetStore.getPreviousAsset($viewingAsset);

    if (previousAsset) {
      const preloadAsset = await assetStore.getPreviousAsset(previousAsset);
      assetViewingStore.setAsset(previousAsset, preloadAsset ? [preloadAsset] : []);
      await navigate({ targetRoute: 'current', assetId: previousAsset.id });
    }

    return !!previousAsset;
  };

  const handleNext = async () => {
    const nextAsset = await assetStore.getNextAsset($viewingAsset);

    if (nextAsset) {
      const preloadAsset = await assetStore.getNextAsset(nextAsset);
      assetViewingStore.setAsset(nextAsset, preloadAsset ? [preloadAsset] : []);
      await navigate({ targetRoute: 'current', assetId: nextAsset.id });
    }

    return !!nextAsset;
  };

  const handleClose = async ({ detail: { asset } }: { detail: { asset: AssetResponseDto } }) => {
    showSkeleton = true;
    assetViewingStore.showAssetViewer(false);
    $gridScrollTarget = { assetId: asset.id, date: null };
    await navigate({ targetRoute: 'current', assetId: null, assetGridScrollTarget: $gridScrollTarget });
  };

  const handleAction = async (action: AssetAction, asset: AssetResponseDto) => {
    switch (action) {
      case removeAction:
      case AssetAction.TRASH:
      case AssetAction.RESTORE:
      case AssetAction.DELETE: {
        // find the next asset to show or close the viewer
        (await handleNext()) || (await handlePrevious()) || (await handleClose({ detail: { asset } }));

        // delete after find the next one
        assetStore.removeAssets([asset.id]);
        break;
      }

      case AssetAction.ARCHIVE:
      case AssetAction.UNARCHIVE:
      case AssetAction.FAVORITE:
      case AssetAction.UNFAVORITE: {
        assetStore.updateAssets([asset]);
        break;
      }

      case AssetAction.ADD: {
        assetStore.addAssets([asset]);
        break;
      }
    }
  };

  let lastAssetMouseEvent: AssetResponseDto | null = null;

  $: if (!lastAssetMouseEvent) {
    assetInteractionStore.clearAssetSelectionCandidates();
  }

  let shiftKeyIsDown = false;

  const deselectAllAssets = () => {
    $isSelectingAllAssets = false;
    assetInteractionStore.clearMultiselect();
  };

  const onKeyDown = (event: KeyboardEvent) => {
    if ($isSearchEnabled) {
      return;
    }

    if (event.key === 'Shift') {
      event.preventDefault();
      shiftKeyIsDown = true;
    }
  };

  const onKeyUp = (event: KeyboardEvent) => {
    if ($isSearchEnabled) {
      return;
    }

    if (event.key === 'Shift') {
      event.preventDefault();
      shiftKeyIsDown = false;
    }
  };

  $: if (!shiftKeyIsDown) {
    assetInteractionStore.clearAssetSelectionCandidates();
  }

  $: if (shiftKeyIsDown && lastAssetMouseEvent) {
    selectAssetCandidates(lastAssetMouseEvent);
  }

  const handleSelectAssetCandidates = (asset: AssetResponseDto | null) => {
    if (asset) {
      selectAssetCandidates(asset);
    }
    lastAssetMouseEvent = asset;
  };

  const handleGroupSelect = (group: string, assets: AssetResponseDto[]) => {
    if ($selectedGroup.has(group)) {
      assetInteractionStore.removeGroupFromMultiselectGroup(group);
      for (const asset of assets) {
        assetInteractionStore.removeAssetFromMultiselectGroup(asset);
      }
    } else {
      assetInteractionStore.addGroupToMultiselectGroup(group);
      for (const asset of assets) {
        handleSelectAsset(asset);
      }
    }
  };

  const handleSelectAssets = async (asset: AssetResponseDto) => {
    if (!asset) {
      return;
    }

    dispatch('select', asset);

    if (singleSelect) {
      element.scrollTop = 0;
      return;
    }

    const rangeSelection = $assetSelectionCandidates.size > 0;
    const deselect = $selectedAssets.has(asset);

    // Select/deselect already loaded assets
    if (deselect) {
      for (const candidate of $assetSelectionCandidates || []) {
        assetInteractionStore.removeAssetFromMultiselectGroup(candidate);
      }
      assetInteractionStore.removeAssetFromMultiselectGroup(asset);
    } else {
      for (const candidate of $assetSelectionCandidates || []) {
        handleSelectAsset(candidate);
      }
      handleSelectAsset(asset);
    }

    assetInteractionStore.clearAssetSelectionCandidates();

    if ($assetSelectionStart && rangeSelection) {
      let startBucketIndex = $assetStore.getBucketIndexByAssetId($assetSelectionStart.id);
      let endBucketIndex = $assetStore.getBucketIndexByAssetId(asset.id);

      if (startBucketIndex === null || endBucketIndex === null) {
        return;
      }

      if (endBucketIndex < startBucketIndex) {
        [startBucketIndex, endBucketIndex] = [endBucketIndex, startBucketIndex];
      }

      // Select/deselect assets in all intermediate buckets
      for (let bucketIndex = startBucketIndex + 1; bucketIndex < endBucketIndex; bucketIndex++) {
        const bucket = $assetStore.buckets[bucketIndex];
        await assetStore.loadBucket(bucket.bucketDate, BucketPosition.Unknown);
        for (const asset of bucket.assets) {
          if (deselect) {
            assetInteractionStore.removeAssetFromMultiselectGroup(asset);
          } else {
            handleSelectAsset(asset);
          }
        }
      }

      // Update date group selection
      for (let bucketIndex = startBucketIndex; bucketIndex <= endBucketIndex; bucketIndex++) {
        const bucket = $assetStore.buckets[bucketIndex];

        // Split bucket into date groups and check each group
        const assetsGroupByDate = splitBucketIntoDateGroups(bucket.assets, $locale);

        for (const dateGroup of assetsGroupByDate) {
          const dateGroupTitle = formatGroupTitle(DateTime.fromISO(dateGroup[0].fileCreatedAt).startOf('day'));
          if (dateGroup.every((a) => $selectedAssets.has(a))) {
            assetInteractionStore.addGroupToMultiselectGroup(dateGroupTitle);
          } else {
            assetInteractionStore.removeGroupFromMultiselectGroup(dateGroupTitle);
          }
        }
      }
    }

    assetInteractionStore.setAssetSelectionStart(deselect ? null : asset);
  };

  const selectAssetCandidates = (asset: AssetResponseDto) => {
    if (!shiftKeyIsDown) {
      return;
    }

    const rangeStart = $assetSelectionStart;
    if (!rangeStart) {
      return;
    }

    let start = $assetStore.assets.indexOf(rangeStart);
    let end = $assetStore.assets.indexOf(asset);

    if (start > end) {
      [start, end] = [end, start];
    }

    assetInteractionStore.setAssetSelectionCandidates($assetStore.assets.slice(start, end + 1));
  };

  const onSelectStart = (e: Event) => {
    if ($isMultiSelectState && shiftKeyIsDown) {
      e.preventDefault();
    }
  };
</script>

<svelte:window on:keydown={onKeyDown} on:keyup={onKeyUp} on:selectstart={onSelectStart} use:shortcuts={shortcutList} />

{#if isShowDeleteConfirmation}
  <DeleteAssetDialog
    size={idsSelectedAssets.length}
    on:cancel={() => (isShowDeleteConfirmation = false)}
    on:confirm={() => handlePromiseError(trashOrDelete(true))}
  />
{/if}

{#if showShortcuts}
  <ShowShortcuts on:close={() => (showShortcuts = !showShortcuts)} />
{/if}

<Scrollbar
  invisible={showSkeleton}
  {assetStore}
  height={viewport.height}
  {timelineY}
  on:scrollTimeline={updateScrollPositon}
/>

<!-- Right margin MUST be equal to the width of immich-scrubbable-scrollbar -->
<section
  id="asset-grid"
  class="scrollbar-hidden h-full overflow-y-auto outline-none pb-[60px] {isEmpty ? 'm-0' : 'ml-4 tall:ml-0 mr-[60px]'}"
  tabindex="-1"
  bind:clientHeight={viewport.height}
  bind:clientWidth={viewport.width}
  bind:this={element}
  on:scroll={() => handleTimelineScroll()}
>
  <!-- skeleton -->
  {#if showSkeleton}
    <div id="skeleton" class="absolute top-0 object-cover mt-8 animate-pulse">
      <div class="mb-2 h-4 w-24 rounded-full bg-immich-primary/20 dark:bg-immich-dark-primary/20" />
      <div class="flex w-[120%] flex-wrap">
        {#each Array.from({ length: 100 }) as _}
          <div class="m-[1px] h-[10em] w-[16em] bg-immich-primary/20 dark:bg-immich-dark-primary/20" />
        {/each}
      </div>
    </div>
  {/if}

  {#if element}
    <div class:invisible={showSkeleton}>
      <slot />
      {#if isEmpty}
        <!-- (optional) empty placeholder -->
        <slot name="empty" />
      {/if}
    </div>

    <section
      bind:this={timelineElement}
      id="virtual-timeline"
      class:invisible={showSkeleton}
      style:height={$assetStore.timelineHeight + 'px'}
    >
      {#each $assetStore.buckets as bucket, index (bucket.bucketDate)}
        <IntersectionObserver
          on:intersected={intersectedHandler}
          on:hidden={() => bucket.cancel()}
          let:intersecting
          top={'750px'}
          bottom={'750px'}
          root={element}
        >
          {@const showGroup = intersecting || bucket === $assetStore.pendingScrollBucket}
          <div id={'bucket_' + bucket.bucketDate} style:height={bucket.bucketHeight + 'px'}>
            {#if showGroup}
              <AssetDateGroup
                assetGridElement={element}
                bottom={'1000px'}
                bind:this={assetGroupCmp[index]}
                {withStacked}
                {showArchiveIcon}
                {assetStore}
                {assetInteractionStore}
                {isSelectionMode}
                {singleSelect}
                on:select={({ detail: group }) => handleGroupSelect(group.title, group.assets)}
                on:shift={handleScrollTimeline}
                on:selectAssetCandidates={({ detail: asset }) => handleSelectAssetCandidates(asset)}
                on:selectAssets={({ detail: asset }) => handleSelectAssets(asset)}
                onScrollTarget={scrollToTarget}
                {onAssetInGrid}
                assets={bucket.assets}
                bucketDate={bucket.bucketDate}
                bucketHeight={bucket.bucketHeight}
                {viewport}
              />
            {/if}
          </div>
        </IntersectionObserver>
      {/each}
    </section>
  {/if}
</section>

<Portal target="body">
  {#if $showAssetViewer}
    {#await import('../asset-viewer/asset-viewer.svelte') then { default: AssetViewer }}
      <AssetViewer
        {withStacked}
        {assetStore}
        asset={$viewingAsset}
        preloadAssets={$preloadAssets}
        {isShared}
        {album}
        on:previous={handlePrevious}
        on:next={handleNext}
        on:close={handleClose}
        on:action={({ detail: action }) => handleAction(action.type, action.asset)}
      />
    {/await}
  {/if}
</Portal>

<style>
  #asset-grid {
    contain: layout;
    scrollbar-width: none;
  }
  @keyframes delayedVisibility {
    to {
      visibility: visible;
    }
  }
  #skeleton {
    visibility: hidden;
    animation: 0s linear 0.3s forwards delayedVisibility;
  }
  #test {
    background: blue;
    position: absolute;
    top: 10px;
    width: 100%;
    height: 100px;
    z-index: 100;
  }
</style>
