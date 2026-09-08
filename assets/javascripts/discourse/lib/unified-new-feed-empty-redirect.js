// Shared by the /feed route and the homepage override so both stay in sync.
export const EMPTY_REDIRECT_ROUTES = {
  latest: "discovery.latest",
  unseen: "discovery.unseen",
  top: "discovery.top",
  categories: "discovery.categories",
  read: "discovery.read",
  hot: "discovery.hot",
};

export function emptyRedirectRouteName(siteSettings) {
  return EMPTY_REDIRECT_ROUTES[
    siteSettings.unified_new_feed_empty_redirect
  ];
}
