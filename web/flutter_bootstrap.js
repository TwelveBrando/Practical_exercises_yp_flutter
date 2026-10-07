{{flutter_js}}
{{flutter_build_config}}

const engineConfig = { canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href, canvasKitVariant: 'full' };

_flutter.loader.load({
  config: engineConfig,
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine(engineConfig);
      await appRunner.runApp();
      document.getElementById('loading')?.remove();
    } catch (error) {
      document.getElementById('startup-error').hidden = false;
      console.error(error);
    }
  }
}).catch(function(error) {
  document.getElementById('startup-error').hidden = false;
  console.error(error);
});
