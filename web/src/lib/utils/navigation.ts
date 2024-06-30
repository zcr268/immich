import { goto } from '$app/navigation';
import { page } from '$app/stores';
import { AppRoute, QueryParameter } from '$lib/constants';
import { getAssetInfo } from '@immich/sdk';
import type { NavigationTarget } from '@sveltejs/kit';
import { get } from 'svelte/store';

export type AssetGridScrollTarget = {
  assetId: string | null | undefined;
  date: string | null | undefined;
};
export const isExternalUrl = (url: string): boolean => {
  return new URL(url, window.location.href).origin !== window.location.origin;
};

export const isPhotosRoute = (route?: string | null) => !!route?.startsWith('/(user)/photos/[[assetId=id]]');
export const isSharedLinkRoute = (route?: string | null) => !!route?.startsWith('/(user)/share/[key]');
export const isSearchRoute = (route?: string | null) => !!route?.startsWith('/(user)/search');
export const isAlbumsRoute = (route?: string | null) => !!route?.startsWith('/(user)/albums/[albumId=id]');
export const isPeopleRoute = (route?: string | null) => !!route?.startsWith('/(user)/people/[personId]');

export const isAssetViewerRoute = (target?: NavigationTarget | null) =>
  !!(target?.route.id?.endsWith('/[[assetId=id]]') && 'assetId' in (target?.params || {}));

export function getAssetInfoFromParam({ assetId, key }: { assetId?: string; key?: string }) {
  return assetId && getAssetInfo({ id: assetId, key });
}

function currentUrlWithoutAsset() {
  const $page = get(page);
  // This contains special casing for the /photos/:assetId route, which hangs directly
  // off / instead of a subpath, unlike every other asset-containing route.
  return isPhotosRoute($page.route.id)
    ? AppRoute.PHOTOS + $page.url.search
    : $page.url.pathname.replace(/(\/photos.*)$/, '') + $page.url.search;
}

export function currentUrlReplaceAssetId(assetId: string) {
  const $page = get(page);
  // this contains special casing for the /photos/:assetId photos route, which hangs directly
  // off / instead of a subpath, unlike every other asset-containing route.
  return isPhotosRoute($page.route.id)
    ? `${AppRoute.PHOTOS}/${assetId}${$page.url.search}`
    : `${$page.url.pathname.replace(/(\/photos.*)$/, '')}/photos/${assetId}${$page.url.search}`;
}

function replaceScrollTarget(url: string, assetGridScrollTarget: AssetGridScrollTarget) {
  const $page = get(page);
  const parsed = new URL(url, $page.url);
  if (assetGridScrollTarget === null || assetGridScrollTarget === undefined) {
    return parsed.pathname;
  }
  const params = new URLSearchParams($page.url.search);
  debugger;
  params.set('asset', assetGridScrollTarget);
  return parsed.pathname + '?' + params.toString();
}

function currentUrl() {
  const $page = get(page);
  const current = $page.url;
  return current.pathname + current.search + current.hash;
}

interface Route {
  /**
   * The route to target, or 'current' to stay on current route.
   */
  targetRoute: string | 'current';
}

interface AssetRoute extends Route {
  targetRoute: 'current';
  assetId: string | null | undefined;
}
interface AssetGridRoute extends Route {
  targetRoute: 'current';
  assetId: string | null | undefined;
  assetGridScrollTarget: AssetGridScrollTarget;
}

type ImmichRoute = AssetRoute | AssetGridRoute;

function isAssetRoute(route: Route): route is AssetRoute {
  return route.targetRoute === 'current' && 'assetId' in route;
}

function isAssetGridRoute(route: Route): route is AssetGridRoute {
  return route.targetRoute === 'current' && 'assetId' in route && 'assetGridScrollTarget' in route;
}

async function navigateAssetRoute(route: AssetRoute) {
  const { assetId } = route;
  const next = assetId ? currentUrlReplaceAssetId(assetId) : currentUrlWithoutAsset();
  const current = currentUrl();
  if (next !== current) {
    await goto(next, { replaceState: false });
  }
}

async function navigateAssetGridRoute(route: AssetGridRoute) {
  const { assetId, assetGridScrollTarget } = route;
  const assetUrl = assetId ? currentUrlReplaceAssetId(assetId) : currentUrlWithoutAsset();
  const next = replaceScrollTarget(assetUrl, assetGridScrollTarget);
  const current = currentUrl();
  if (next !== current) {
    await goto(next, { replaceState: true, noScroll: true, keepFocus: true });
  }
}

export function navigate(change: ImmichRoute): Promise<void> {
  if (isAssetGridRoute(change)) {
    return navigateAssetGridRoute(change);
  } else if (isAssetRoute(change)) {
    return navigateAssetRoute(change);
  }
  // future navigation requests here
  throw `Invalid navigation: ${JSON.stringify(change)}`;
}

export const clearQueryParam = async (queryParam: string, url: URL) => {
  if (url.searchParams.has(queryParam)) {
    url.searchParams.delete(queryParam);
    await goto(url, { keepFocus: true });
  }
};
