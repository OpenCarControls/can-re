let pluginApi: any = null;

export const setApi = (api: any) => {
    pluginApi = api;
};

export const getApi = () => {
    if (!pluginApi) {
        throw new Error("Plugin API has not been initialized!");
    }
    return pluginApi;
};
