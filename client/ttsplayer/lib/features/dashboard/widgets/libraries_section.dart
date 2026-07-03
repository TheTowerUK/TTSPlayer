import 'package:flutter/material.dart';

import '../../../models/media_folder.dart';
import '../../../screens/folder_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/library_card.dart';
import '../../../widgets/section_header.dart';

class LibrariesSection extends StatelessWidget {
  final List<MediaFolder> libraries;

  const LibrariesSection({super.key, required this.libraries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Libraries'),
        const SizedBox(height: AppSpacing.md),
        if (libraries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No libraries found.',
              subtitle: 'Run a scan to populate your library.',
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: AppSpacing.gridLibrary,
                mainAxisSpacing: AppSpacing.gridGap,
                crossAxisSpacing: AppSpacing.gridGap,
                childAspectRatio: 0.95,
              ),
              itemCount: libraries.length,
              itemBuilder: (context, index) {
                final folder = libraries[index];
                return LibraryCard(
                  folder: folder,
                  onBrowse: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderScreen(
                        folderPath: folder.path,
                        folderName: folder.name,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
