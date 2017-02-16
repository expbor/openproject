import {timelineCellClassName} from '../timeline-cell-builder';
import {WorkPackageEditForm} from '../../../wp-edit-form/work-package-edit-form';
import {locateRow} from '../../helpers/wp-table-row-helpers';
import {WorkPackageTable} from '../../wp-fast-table';
import {WorkPackageTableRow} from '../../wp-table.interfaces';
import {SingleRowBuilder} from './single-row-builder';

export class EditingRowBuilder extends SingleRowBuilder {

  /**
   * Refresh a row that is currently being edited, that is, some edit fields may be open
   */
  public refreshEditing(row:WorkPackageTableRow, editForm:WorkPackageEditForm):HTMLElement|null {
    // Get the row for the WP if refreshing existing
    const rowElement = row.element || locateRow(row.workPackageId);
    if (!rowElement) {
      return null;
    }

    // Detach all existing columns
    const jRow = jQuery(rowElement);
    const tds = jRow.find('td').detach();

    // Iterate all columns, reattaching or rendering new columns
    this.columns.forEach((column:string) => {
      const oldTd = tds.filter(`td.${column}`);

      // Reattach the column if its currently being edited
      if (editForm.activeFields[column] && oldTd.length) {
        rowElement.appendChild(oldTd[0]);
      } else {
        const cell = this.cellBuilder.build(row.object, column);
        rowElement.appendChild(cell);
      }
    });

    // Last table column: details link
    this.detailsLinkBuilder.build(row.object, rowElement);

    // Timeline column
    jRow.append(tds.filter(`.${timelineCellClassName}`));

    return rowElement;
  }
}
