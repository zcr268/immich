<script lang="ts">
  import IntersectionObserver from '$lib/components/asset-viewer/intersection-observer.svelte';
  import Icon from '$lib/components/elements/icon.svelte';
  import type { AssetInteractionStore } from '$lib/stores/asset-interaction.store';
  import { assetViewingStore } from '$lib/stores/asset-viewing.store';
  import { AssetBucket, type AssetStore, type Viewport } from '$lib/stores/assets.store';
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
  import { createEventDispatcher, tick } from 'svelte';
  import { fly } from 'svelte/transition';
  import Thumbnail from '../assets/thumbnail/thumbnail.svelte';
  import { handlePromiseError } from '$lib/utils';

  export let element: HTMLElement | undefined = undefined;
  export let assets: AssetResponseDto[];
  export let bucketDate: string;
  export let bucketHeight: number;
  export let isSelectionMode = false;
  export let viewport: Viewport;
  export let singleSelect = false;
  export let withStacked = false;
  export let showArchiveIcon = false;
  export let something: HTMLElement | undefined = undefined;
  export let bottom: string | undefined = undefined;
  export let assetStore: AssetStore;
  export let assetInteractionStore: AssetInteractionStore;
  export let onScrollTarget: (({ target, offset }: { target: AssetBucket; offset: number }) => void) | undefined =
    undefined;
  export let onAssetInGrid: (asset: AssetResponseDto) => void | undefined = undefined;
  /* TODO figure out a way to calculate this*/
  const TITLE_HEIGHT = 51;

  function nextRowIndex(geometry: GeometryType, start: number) {
    const offsetIndex = geometry.boxes.slice(start).findIndex((box) => box.left === 0);
    return offsetIndex === -1 ? -1 : offsetIndex + start;
  }

  function findLeftMost(geometry: GeometryType, top: number) {
    // note: every boxes.left === 0 indicates start of new row
    const { topOffset: geoTopOffset } = geometry;
    // const t = top;
    for (let j = 0; j < geometry.gridHeights.length; j++) {
      const rowTop = geometry.gridHeights[j] + geoTopOffset;
      // let nextRowTop = 0;
      // if (j === geometry.gridHeights.length - 1) {
      //   geometry.containerHeight;
      // }
      const nextRowTop =
        (j === geometry.gridHeights.length - 1 ? geometry.containerHeight : geometry.gridHeights[j + 1]) + geoTopOffset;
      if (top >= rowTop - 0.2 && top < nextRowTop) {
        // console.log('ok');
        return geometry.assets[geometry.gridOffsets[j]];
      }
    }
    // debugger;
    // for (let j = 0; j < geometry.boxes.length; ) {
    //   const rowTop = geometry.boxes[j].top + geoTopOffset;
    //   const nextRow = nextRowIndex(geometry, j + 1);
    //   const nextRowTop = (nextRow === -1 ? geometry.containerHeight : geometry.boxes[nextRow].top) + geoTopOffset;
    //   // 0.2 is row height tolerance
    //   if (top >= rowTop - 0.2 && top < nextRowTop) {
    //     return geometry.assets[j];
    //   }

    //   if (nextRow === -1) {
    //     break;
    //   }
    //   j = nextRow;
    // }
  }

  export function findAssetAtTopLeftPosition(top: number) {
    if (top < 0) {
      return;
    }

    for (let i = 0; i < geometry.length; i++) {
      const reltop = top - i * TITLE_HEIGHT;

      const geo = geometry[i];
      const cur_number = geo.topOffset;
      const next_number = i === geometry.length - 1 ? bucketHeight : geometry[i + 1].topOffset;

      if (reltop >= cur_number && reltop < next_number) {
        // console.log(
        //   'top!',
        //   reltop,
        //   top,
        //   top - i * TITLE_HEIGHT,
        //   geo.topOffset,
        //   geo.containerHeight + geo.topOffset,
        //   geo.assets,
        //   geo.gridHeights,
        // );
        // return findLeftMost(geo, top - i * TITLE_HEIGHT);
        return findLeftMost(geo, reltop);
      } else {
        // console.log('not ', reltop, cur_number, next_number);
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

  type GeometryType = Omit<ReturnType<typeof justifiedLayout>, 'boxes'> & {
    boxes: (LayoutBox & {
      gridrow: number;
    })[];
    containerWidth: number;
    assets: AssetResponseDto[];
    topOffset: number;
    gridOffsets: number[];
    gridHeights: number[];
  };

  let geometry: GeometryType[] = [];

  const scrollToThumbnail = (thumbnailElement: HTMLElement) => {
    const thumbBox = thumbnailElement?.offsetParent as HTMLElement;
    const imageGrid = thumbBox.offsetParent as HTMLElement;
    const section = imageGrid.offsetParent as HTMLElement;

    const offsetFromImageGrid = thumbBox.offsetTop;
    const previousSections = imageGrid.offsetTop;

    const sectionOffset = section.offsetTop;
    const offset = offsetFromImageGrid + previousSections + sectionOffset - TITLE_HEIGHT;

    const bucket = $assetStore.buckets.find((bucket) => bucket.bucketDate === section.dataset.bucketDate);

    onScrollTarget?.({ target: bucket!, offset });
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
    if (bucketDate === '2024-03-01T00:00:00.000Z') {
      // debugger;
    }
    geometry = [];
    let topOffset = 0;
    for (const [k, group] of assetsGroupByDate.entries()) {
      const layoutResult = justifiedLayout(
        group.map((assetGroup) => getAssetRatio(assetGroup)),
        layoutOptions,
      );
      const geo = {
        ...layoutResult,
        containerWidth: calculateWidth(layoutResult.boxes),
        assets: group,
        topOffset,
        gridOffsets: [],
        gridHeights: [],
      } as unknown as GeometryType;

      let index = -1;
      for (const [i, box] of geo.boxes.entries()) {
        if (box.left === 0) {
          geo.gridOffsets.push(i);
          if (index === -1) {
            geo.gridHeights.push(box.top);
          } else {
            geo.gridHeights.push(box.top);
          }
        }
        box.gridrow = index;
      }

      geometry.push(geo);
      // const offset = k * TITLE_HEIGHT;
      const offset = 0;
      topOffset += layoutResult.containerHeight + offset;
    }
  }

  $: {
    if (actualBucketHeight && actualBucketHeight !== 0 && actualBucketHeight != bucketHeight) {
      const heightDelta = assetStore.updateBucket(bucketDate, actualBucketHeight);
      if (heightDelta !== 0) {
        handlePromiseError(tick().then(() => scrollTimeline(heightDelta)));
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
  class="flex flex-wrap gap-x-12"
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
      class="flex flex-col"
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
        data-geo-top={geometry[groupIndex].topOffset}
        data-geo-idx={groupIndex}
        style="height: {geometry[groupIndex].containerHeight}px;width: {geometry[groupIndex].containerWidth}px"
      >
        {#each groupAssets as asset, index (asset.id)}
          {@const box = geometry[groupIndex].boxes[index]}
          <div
            data-gridrow-top={geometry[groupIndex].gridHeights[geometry[groupIndex].boxes[index].gridrow]}
            class="absolute"
            style="width: {box.width}px; height: {box.height}px; top: {box.top}px; left: {box.left}px"
          >
            <IntersectionObserver
              root={something}
              top={'-51px'}
              bottom={`-99%`}
              right={'-99%'}
              data={asset.id}
              once={false}
              on:intersected={() => {
                // debugger;
                console.log('cool', asset.id);
                onAssetInGrid(asset);
              }}
              on:hidden={() => {
                // debugger;
                // console.log('hidden', asset.id);
              }}
            >
              <Thumbnail
                root={something}
                {bottom}
                scrollTarget={$assetStore.pendingScrollAssetId === asset.id}
                showStackedIcon={withStacked}
                {showArchiveIcon}
                {asset}
                {groupIndex}
                onScrollTarget={scrollToThumbnail}
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
                selected={$selectedAssets.has(asset) || $assetStore.albumAssets.has(asset.id)}
                selectionCandidate={$assetSelectionCandidates.has(asset)}
                disabled={$assetStore.albumAssets.has(asset.id)}
                thumbnailWidth={box.width}
                thumbnailHeight={box.height}
              />
            </IntersectionObserver>
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
