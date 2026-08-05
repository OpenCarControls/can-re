import * as React from 'react';
import * as ReactDOM from 'react-dom';
import * as ReactDOMClient from 'react-dom/client';
import * as MuiMaterial from '@mui/material';
import * as MuiIconsMaterial from '@mui/icons-material';
import * as EmotionReact from '@emotion/react';
import * as EmotionStyled from '@emotion/styled';
import * as FlexLayout from 'flexlayout-react';
import * as jsxRuntime from 'react/jsx-runtime';

// Expose critical libraries to the global window object.
// This allows future plugins to be bundled treating these as "external" dependencies,
// effectively sharing the core application's React instance and preventing massive bundle bloat.

if (typeof window !== 'undefined') {
  (window as any).React = React;
  (window as any).ReactDOM = ReactDOM;
  (window as any).ReactDOMClient = ReactDOMClient;
  (window as any).MuiMaterial = MuiMaterial;
  (window as any).MuiIconsMaterial = MuiIconsMaterial;
  (window as any).EmotionReact = EmotionReact;
  (window as any).EmotionStyled = EmotionStyled;
  (window as any).FlexLayout = FlexLayout;
  (window as any).ReactJsxRuntime = jsxRuntime;
}
