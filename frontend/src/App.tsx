import React from 'react';
import { RouterProvider } from 'react-router-dom';
import { router } from './app/router';
import './i18n';

export const App: React.FC = () => {
  return <RouterProvider router={router} />;
};

export default App;
