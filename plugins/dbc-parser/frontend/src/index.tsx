
import FolderOpenIcon from '@mui/icons-material/FolderOpen';

export function setup({ registerToolbarAction, api }: any) {
    registerToolbarAction({
        id: 'dbc-parser.load',
        group: 'File',
        label: 'Load DBC',
        icon: <FolderOpenIcon />,
        order: 200, // Put it after Load Log
        onClick: async () => {
            try {
                const res = await api.call_service('dbc.load_file');
                if (res && res.success) {
                    window.dispatchEvent(new CustomEvent('dbcLoaded'));
                } else if (res && res.error) {
                    alert("Error loading DBC: " + res.error);
                }
            } catch (e) {
                console.error(e);
                alert("Failed to load DBC");
            }
        }
    });
}
