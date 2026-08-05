import { createRoot } from 'react-dom/client';
import { FolderOpen as FolderOpenIcon } from '@mui/icons-material';
import { AddCircleOutlined as AddCircleOutlineIcon } from '@mui/icons-material';
import { Close as CloseIcon } from '@mui/icons-material';
import { Edit as EditIcon } from '@mui/icons-material';
import { DbcEditorModal } from './DbcEditorModal';

export function setup({ registerToolbarAction, unregisterToolbarAction, api }: any) {
    let root: any = null;
    let isLoaded = false;
    // let loadedFilePath: string | null = null;

    const renderEditor = () => {
        if (!document.getElementById('dbc-editor-root')) {
            const div = document.createElement('div');
            div.id = 'dbc-editor-root';
            document.body.appendChild(div);
            root = createRoot(div);
        }
        root.render(<DbcEditorModal api={api} updateToolbar={updateToolbar} />);
    };

    const updateToolbar = async () => {
        try {
            const state = await api.call_service('dbc.get_state');
            isLoaded = state && state.success;
            // loadedFilePath = isLoaded ? state.file_path : null;
            
            // Clear existing
            unregisterToolbarAction('dbc-parser.load');
            unregisterToolbarAction('dbc-parser.create');
            unregisterToolbarAction('dbc-parser.unload');
            unregisterToolbarAction('dbc-parser.edit');
            unregisterToolbarAction('dbc-parser.new');

            if (!isLoaded) {
                registerToolbarAction({
                    id: 'dbc-parser.load',
                    group: 'File',
                    label: 'Load DBC',
                    icon: <FolderOpenIcon />,
                    order: 200,
                    onClick: async () => {
                        const res = await api.call_service('dbc.load_file');
                        if (res && res.success) {
                            window.dispatchEvent(new CustomEvent('dbcLoaded'));
                            updateToolbar();
                        } else if (res && res.error) {
                            alert("Error loading DBC: " + res.error);
                        }
                    }
                });

                registerToolbarAction({
                    id: 'dbc-parser.create',
                    group: 'File',
                    label: 'Create DBC',
                    icon: <AddCircleOutlineIcon />,
                    order: 201,
                    onClick: async () => {
                        const res = await api.call_service('dbc.new_file');
                        if (res && res.success) {
                            window.dispatchEvent(new CustomEvent('dbcLoaded'));
                            updateToolbar();
                            window.dispatchEvent(new CustomEvent('openDbcEditor'));
                        }
                    }
                });
            } else {
                registerToolbarAction({
                    id: 'dbc-parser.edit',
                    group: 'File',
                    label: 'Edit DBC',
                    icon: <EditIcon />,
                    order: 200,
                    onClick: () => {
                        window.dispatchEvent(new CustomEvent('openDbcEditor'));
                    }
                });

                registerToolbarAction({
                    id: 'dbc-parser.new',
                    group: 'File',
                    label: 'New DBC',
                    icon: <AddCircleOutlineIcon />,
                    order: 201,
                    onClick: async () => {
                        const res = await api.call_service('dbc.new_file');
                        if (res && res.success) {
                            window.dispatchEvent(new CustomEvent('dbcLoaded'));
                            updateToolbar();
                            window.dispatchEvent(new CustomEvent('openDbcEditor'));
                        }
                    }
                });

                registerToolbarAction({
                    id: 'dbc-parser.unload',
                    group: 'File',
                    label: 'Unload DBC',
                    icon: <CloseIcon />,
                    order: 202,
                    onClick: async () => {
                        await api.call_service('dbc.unload_file');
                        window.dispatchEvent(new CustomEvent('dbcUnloaded'));
                        updateToolbar();
                    }
                });
            }
        } catch (e) {
            console.error(e);
        }
    };

    updateToolbar();
    renderEditor();
}
