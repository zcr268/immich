<script lang="ts">
  import Icon from '$lib/components/elements/icon.svelte';
  import type { AssetInteractionStore } from '$lib/stores/asset-interaction.store';
  import { assetViewingStore } from '$lib/stores/asset-viewing.store';
  import { BucketPosition, type AssetStore, type Viewport } from '$lib/stores/assets.store';
  import { locale } from '$lib/stores/preferences.store';
  import { getAssetRatio } from '$lib/utils/asset-utils';
  import {
    calculateWidth,
    formatGroupTitle,
    fromLocalDateTime,
    splitBucketIntoDateGroups,
    type LayoutBox,
  } from '$lib/utils/timeline-util';
  import type { AssetResponseDto } from '@immich/sdk';
  import { mdiCheckCircle, mdiCircleOutline } from '@mdi/js';
  import justifiedLayout from 'justified-layout';
  import { createEventDispatcher, onMount, tick } from 'svelte';
  import { fly } from 'svelte/transition';
  import Thumbnail from '../assets/thumbnail/thumbnail.svelte';

  export let element: HTMLElement | undefined = undefined;
  export let assets: AssetResponseDto[];
  export let bucketDate: string;
  export let bucketHeight: number;
  export let isSelectionMode = false;
  export let viewport: Viewport;
  export let singleSelect = false;
  export let withStacked = false;
  export let showArchiveIcon = false;

  export let assetStore: AssetStore;
  export let assetInteractionStore: AssetInteractionStore;

  function nextRowIndex(geometry: GeometryType, start: number) {
    const offsetIndex = geometry.boxes.slice(start).findIndex((box) => box.left === 0);
    return offsetIndex === -1 ? -1 : offsetIndex + start;
  }

  function findLeftMost(geometry: GeometryType, top: number) {
    // note: every boxes.left === 0 indicates start of new row
    const { topOffset: geoTopOffset } = geometry;
    let rowTopOffset = 0;
    for (let j = 0; j < geometry.boxes.length; ) {
      const rowTop = geometry.boxes[j].top + geoTopOffset;
      const nextRow = nextRowIndex(geometry, j + 1);
      const nextRowTop = (nextRow === -1 ? geometry.containerHeight : geometry.boxes[nextRow].top) + geoTopOffset;
      if (top >= rowTop && top < nextRowTop) {
        return geometry.assets[j];
      }
      rowTopOffset += nextRowTop;
      if (nextRow === -1) break;
      j = nextRow;
    }
  }
  export function findAssetAtTopLeftPosition(top: number) {
    if (top < 0) return;

    let i = 0;
    for (let i = 0; i < geometry.length; i++) {
      const geo = geometry[i];
      const cur_number = geo.topOffset;
      const next_number = i === geometry.length - 1 ? bucketHeight : geometry[i + 1].topOffset;

      if (top >= cur_number && top < next_number) {
        return findLeftMost(geo, top);
      }
    }
  }

  const { selectedGroup, selectedAssets, assetSelectionCandidates, isMultiSelectState } = assetInteractionStore;
  const dispatch = createEventDispatcher<{
    select: { title: string; assets: AssetResponseDto[] };
    selectAssets: AssetResponseDto;
    selectAssetCandidates: AssetResponseDto | null;
    shift: { heightDelta: number };
  }>();

  let isMouseOverGroup = false;
  let actualBucketHeight: number;
  let hoveredDateGroup = '';
  let assetsGroupByDate: AssetResponseDto[][];

  type GeometryType = ReturnType<typeof justifiedLayout> & {
    containerWidth: number;
    assets: AssetResponseDto[];
    topOffset: number;
  };

  let geometry: GeometryType[] = [];

  let handle = (thumbnailElement: HTMLElement) => {
    const thumbBox = thumbnailElement?.offsetParent as HTMLElement;
    const imageGrid = thumbBox.offsetParent as HTMLElement;
    const section = imageGrid.offsetParent as HTMLElement;
    const sectionTitle = imageGrid.previousElementSibling as HTMLElement;

    const offsetFromImageGrid = thumbBox.offsetTop;
    const previousSections = imageGrid.offsetTop;
    const headerSize = sectionTitle.getBoundingClientRect().height;

    const sectionOffset = section.offsetTop;
    const offset = offsetFromImageGrid + previousSections + sectionOffset - headerSize;

    const buckets = $assetStore.buckets;

    for (const bucket of buckets) {
      if (bucket.bucketDate === section.dataset.bucketDate) {
        break;
      }
      bucket.position = BucketPosition.Above;
    }

    document.querySelector('#asset-grid')?.scrollTo({ top: offset });

    $assetStore.clearPendingScroll();
  };

  $: {
    assetsGroupByDate = splitBucketIntoDateGroups(assets, $locale);
    const layoutOptions = {
      boxSpacing: 2,
      containerWidth: Math.floor(viewport.width),
      containerPadding: 0,
      targetRowHeightTolerance: 0.15,
      targetRowHeight: 235,
    };
    geometry = [];
    let topOffset = 0;
    for (let group of assetsGroupByDate) {
      const layoutResult = justifiedLayout(
        group.map((assetGroup) => getAssetRatio(assetGroup)),
        layoutOptions,
      );
      const geo = {
        ...layoutResult,
        containerWidth: calculateWidth(layoutResult.boxes),
        assets: group,
        topOffset,
      };
      geometry.push(geo);
      topOffset += layoutResult.containerHeight;
    }
  }

  $: {
    if (actualBucketHeight && actualBucketHeight !== 0 && actualBucketHeight != bucketHeight) {
      const heightDelta = assetStore.updateBucket(bucketDate, actualBucketHeight);
      if (heightDelta !== 0) {
        tick().then(() => scrollTimeline(heightDelta));
      }
    }
  }

  function scrollTimeline(heightDelta: number) {
    dispatch('shift', {
      heightDelta,
    });
  }

  const handleSelectGroup = (title: string, assets: AssetResponseDto[]) => dispatch('select', { title, assets });

  const assetSelectHandler = (asset: AssetResponseDto, assetsInDateGroup: AssetResponseDto[], groupTitle: string) => {
    dispatch('selectAssets', asset);

    // Check if all assets are selected in a group to toggle the group selection's icon
    let selectedAssetsInGroupCount = assetsInDateGroup.filter((asset) => $selectedAssets.has(asset)).length;

    // if all assets are selected in a group, add the group to selected group
    if (selectedAssetsInGroupCount == assetsInDateGroup.length) {
      assetInteractionStore.addGroupToMultiselectGroup(groupTitle);
    } else {
      assetInteractionStore.removeGroupFromMultiselectGroup(groupTitle);
    }
  };

  const assetMouseEventHandler = (groupTitle: string, asset: AssetResponseDto | null) => {
    // Show multi select icon on hover on date group
    hoveredDateGroup = groupTitle;

    if ($isMultiSelectState) {
      dispatch('selectAssetCandidates', asset);
    }
  };
</script>

<section
  id="asset-group-by-date"
  class="flex flex-col flex-wrap gap-x-12"
  data-bucket-date={bucketDate}
  bind:clientHeight={actualBucketHeight}
  bind:this={element}
>
  {#each assetsGroupByDate as groupAssets, groupIndex (groupAssets[0].id)}
    {@const asset = groupAssets[0]}
    {@const groupTitle = formatGroupTitle(fromLocalDateTime(asset.localDateTime).startOf('day'))}
    <!-- Asset Group By Date -->

    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div
      class="contents"
      on:mouseenter={() => {
        isMouseOverGroup = true;
        assetMouseEventHandler(groupTitle, null);
      }}
      on:mouseleave={() => {
        isMouseOverGroup = false;
        assetMouseEventHandler(groupTitle, null);
      }}
    >
      <!-- Date group title -->
      <div
        data-group-idx={groupIndex}
        class="flex z-[100] sticky top-0 pt-7 pb-5 h-6 place-items-center text-xs font-medium text-immich-fg bg-immich-bg dark:bg-immich-dark-bg dark:text-immich-dark-fg md:text-sm"
        style="width: {geometry[groupIndex].containerWidth}px"
      >
        {#if !singleSelect && ((hoveredDateGroup == groupTitle && isMouseOverGroup) || $selectedGroup.has(groupTitle))}
          <div
            transition:fly={{ x: -24, duration: 200, opacity: 0.5 }}
            class="inline-block px-2 hover:cursor-pointer"
            on:click={() => handleSelectGroup(groupTitle, groupAssets)}
            on:keydown={() => handleSelectGroup(groupTitle, groupAssets)}
          >
            {#if $selectedGroup.has(groupTitle)}
              <Icon path={mdiCheckCircle} size="24" color="#4250af" />
            {:else}
              <Icon path={mdiCircleOutline} size="24" color="#757575" />
            {/if}
          </div>
        {/if}

        <span class="w-full truncate first-letter:capitalize" title={groupTitle}>
          {groupTitle}
        </span>
      </div>

      <!-- Image grid -->
      <div
        class="relative"
        style="height: {geometry[groupIndex].containerHeight}px;width: {geometry[groupIndex].containerWidth}px"
      >
        {#each groupAssets as asset, index (asset.id)}
          {@const box = geometry[groupIndex].boxes[index]}
          <!-- {console.log('box', box)} -->
          <div
            class="absolute"
            style="width: {box.width}px; height: {box.height}px; top: {box.top}px; left: {box.left}px"
          >
            <Thumbnail
              scrollTarget={$assetStore.pendingScrollAssetId === asset.id}
              showStackedIcon={withStacked}
              {showArchiveIcon}
              {asset}
              {groupIndex}
              onScrollTargetElementAdded={handle}
              onClick={(asset, event) => {
                if (isSelectionMode || $isMultiSelectState) {
                  event.preventDefault();
                  assetSelectHandler(asset, groupAssets, groupTitle);
                  return;
                }

                assetViewingStore.setAsset(asset);
              }}
              on:select={() => assetSelectHandler(asset, groupAssets, groupTitle)}
              on:mouse-event={() => assetMouseEventHandler(groupTitle, asset)}
              on:element-scrolled={() => $assetStore.clearPendingScroll()}
              selected={$selectedAssets.has(asset) || $assetStore.albumAssets.has(asset.id)}
              selectionCandidate={$assetSelectionCandidates.has(asset)}
              disabled={$assetStore.albumAssets.has(asset.id)}
              thumbnailWidth={box.width}
              thumbnailHeight={box.height}
            />
          </div>
        {/each}
      </div>
    </div>
  {/each}
</section>

<style>
  #asset-group-by-date {
    contain: layout;
  }
</style>
