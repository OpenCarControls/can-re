
import StorageIcon from '@mui/icons-material/Storage';

export function setup({ registerToolbarAction, api }: any) {
    registerToolbarAction({
        id: 'canlog-provider.load',
        group: 'File',
        label: 'Load Log',
        icon: <StorageIcon />,
        order: 100,
        onClick: async () => {
            try {
                const res = await api.call_service('canlog_provider.load_file');
                if (res && res.success) {
                    window.dispatchEvent(new CustomEvent('logLoaded', { detail: { count: res.total_count } }));
                } else if (res && res.error) {
                    alert("Error loading Log: " + res.error);
                }
            } catch (e) {
                console.error(e);
                alert("Failed to load Log");
            }
        }
    });
}
