import React, { useState } from 'react';
import { Eye, ZoomIn, X } from 'lucide-react';
import fundusGood from '../../assets/demo/fundus-good.jpg';
import fundusPoorBlur from '../../assets/demo/fundus-poor-blur.jpg';
import fundusPoorDark from '../../assets/demo/fundus-poor-dark.jpg';
import fundusPriority from '../../assets/demo/fundus-priority.jpg';
import fundusReview from '../../assets/demo/fundus-review.jpg';

interface FundusImageProps {
  src: string;
  alt?: string;
  size?: 'thumb' | 'preview' | 'full';
  eye?: 'RIGHT' | 'LEFT';
  isDemoSample?: boolean;
  className?: string;
  allowZoom?: boolean;
}

export const FundusImage: React.FC<FundusImageProps> = ({
  src,
  alt = 'Retinal fundus photography',
  size = 'preview',
  eye,
  isDemoSample = true,
  className = '',
  allowZoom = true,
}) => {
  const [loaded, setLoaded] = useState(false);
  const [zoomed, setZoomed] = useState(false);

  const demoImages: Record<string, string> = {
    '/src/assets/demo/fundus-good.jpg': fundusGood,
    '/src/assets/demo/fundus-poor-blur.jpg': fundusPoorBlur,
    '/src/assets/demo/fundus-poor-dark.jpg': fundusPoorDark,
    '/src/assets/demo/fundus-priority.jpg': fundusPriority,
    '/src/assets/demo/fundus-review.jpg': fundusReview,
  };
  const resolvedSrc = demoImages[src] || src;

  const sizeClasses = {
    thumb: 'w-16 h-16 rounded-lg',
    preview: 'w-full max-w-sm h-64 sm:h-72 rounded-xl',
    full: 'w-full h-80 sm:h-96 rounded-2xl',
  }[size];

  return (
    <>
      <div className={`relative overflow-hidden bg-slate-950 flex items-center justify-center border border-slate-800 shadow-sm ${sizeClasses} ${className}`}>
        {/* Loading skeleton */}
        {!loaded && (
          <div className="absolute inset-0 flex items-center justify-center bg-slate-900 text-slate-400">
            <Eye className="w-8 h-8 animate-pulse text-brand-400/60" />
          </div>
        )}

        <img
          src={resolvedSrc}
          alt={alt}
          onLoad={() => setLoaded(true)}
          className={`w-full h-full object-contain select-none transition-opacity duration-200 ${
            loaded ? 'opacity-100' : 'opacity-0'
          }`}
          loading="lazy"
        />

        {/* Eye badge */}
        {eye && (
          <span className="absolute top-2 left-2 px-2 py-0.5 text-xs font-bold rounded bg-black/75 text-white backdrop-blur-xs border border-white/20">
            {eye === 'RIGHT' ? 'OD (Right Eye)' : 'OS (Left Eye)'}
          </span>
        )}

        {/* Demo Sample indicator */}
        {isDemoSample && size !== 'thumb' && (
          <span className="absolute bottom-2 left-2 px-1.5 py-0.5 text-[10px] font-medium tracking-wide uppercase rounded bg-slate-900/80 text-slate-300 border border-slate-700">
            Demo Sample
          </span>
        )}

        {/* Zoom trigger */}
        {allowZoom && size !== 'thumb' && (
          <button
            type="button"
            onClick={() => setZoomed(true)}
            className="absolute bottom-2 right-2 p-1.5 rounded-lg bg-black/75 text-white hover:bg-black border border-white/20 transition-colors"
            title="Inspect Fundus Detail"
            aria-label="Zoom in fundus image"
          >
            <ZoomIn className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Modal Zoom View */}
      {zoomed && (
        <div
          className="fixed inset-0 z-50 bg-black/95 flex flex-col items-center justify-center p-4"
          onClick={() => setZoomed(false)}
        >
          <div className="relative max-w-2xl w-full flex flex-col items-center">
            <div className="w-full flex justify-between items-center text-white mb-3">
              <span className="text-sm font-semibold flex items-center gap-2">
                <Eye className="w-4 h-4 text-brand-400" />
                {alt} {eye && `• ${eye === 'RIGHT' ? 'Right Eye (OD)' : 'Left Eye (OS)'}`}
              </span>
              <button
                type="button"
                onClick={() => setZoomed(false)}
                className="p-2 rounded-lg bg-white/10 hover:bg-white/20 text-white"
                aria-label="Close zoomed view"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="w-full max-h-[75vh] flex items-center justify-center overflow-hidden rounded-xl bg-black border border-slate-800">
              <img
                src={resolvedSrc}
                alt={alt}
                className="max-h-[75vh] max-w-full object-contain"
              />
            </div>
            <p className="text-xs text-slate-400 mt-2">
              High resolution view for retinal vascular and macula inspection
            </p>
          </div>
        </div>
      )}
    </>
  );
};
