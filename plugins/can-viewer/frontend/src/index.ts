import { LogViewer } from './LogViewer';
import { FrameDetails } from './FrameDetails';
import { setApi } from './pluginApi';

export function setup(context: any) {
    const { registerPanel, api } = context;
    setApi(api);

    registerPanel({
        id: 'logViewer',
        name: 'CAN Log',
        component: LogViewer,
        defaultZone: 'primary',
        allowMultiple: false,
    });

    registerPanel({
        id: 'frameDetails',
        name: 'Frame Details',
        component: FrameDetails,
        defaultZone: 'secondary',
        allowMultiple: false,
    });
}
