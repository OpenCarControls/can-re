import { LogViewer } from './LogViewer';
import { SignalDetails } from './SignalDetails';
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
        id: 'signalDetails',
        name: 'Signal Details',
        component: SignalDetails,
        defaultZone: 'secondary',
        allowMultiple: false,
    });
}
