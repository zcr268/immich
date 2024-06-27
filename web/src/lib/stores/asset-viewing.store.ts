import { getKey } from '$lib/utils';
import { navigate } from '$lib/utils/navigation';
import { getAssetInfo, type AssetResponseDto } from '@immich/sdk';
import { get, writable } from 'svelte/store';

function createAssetViewingStore() {
  const viewingAssetStoreState = writable<AssetResponseDto>();
  const preloadAssets = writable<AssetResponseDto[]>([]);
  const viewState = writable<boolean>(false);
  const scrollTarget = writable<string | undefined>();

  const setAsset = (asset: AssetResponseDto, assetsToPreload: AssetResponseDto[] = []) => {
    preloadAssets.set(assetsToPreload);
    viewingAssetStoreState.set(asset);
    viewState.set(true);
  };

  const setAssetId = async (id: string) => {
    const asset = await getAssetInfo({ id, key: getKey() });
    setAsset(asset);
  };

  const showAssetViewer = (show: boolean) => {
    viewState.set(show);
  };

  const setGridScrollTarget = async (assetGridScrollTarget: string) => {
    scrollTarget.set(assetGridScrollTarget);
    const assetId = get(viewState) ? get(viewingAssetStoreState)?.id : null;
    await navigate({ targetRoute: 'current', assetId, assetGridScrollTarget });
  };

  return {
    asset: {
      subscribe: viewingAssetStoreState.subscribe,
    },
    preloadAssets: {
      subscribe: preloadAssets.subscribe,
    },
    isViewing: {
      subscribe: viewState.subscribe,
      set: viewState.set,
    },
    gridScrollTarget: {
      subscribe: scrollTarget.subscribe,
    },
    setGridScrollTarget,
    setAsset,
    setAssetId,
    showAssetViewer,
  };
}

export const assetViewingStore = createAssetViewingStore();
